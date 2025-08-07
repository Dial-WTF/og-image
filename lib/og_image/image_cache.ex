defmodule OgImage.ImageCache do
  @moduledoc """
  Directory-backed cache with a max size (bytes) and FIFO eviction (oldest first),
  scoped to a single BEAM node (per-machine).

  - Atomic writes: temp file + rename.
  - FIFO = file `mtime` (oldest first).
  - Local, non-blocking eviction lock via ETS (no cross-node coordination).
  """

  @lock_table :image_cache_locks
  @default_ext "bin"

  ## ——— Public API ———

  @doc """
  Store `data` under `key` in `cache_dir`, enforce `max_bytes`, and return the absolute path.

  * `key` is hashed to a safe filename; optionally pass `ext` like \"png\".
  * If the cache is (briefly) over capacity due to a skipped eviction (another
    process is evicting), the next write will clean it up.
  """
  def put(cache_dir, key, data, max_bytes, ext \\ @default_ext)
      when is_binary(cache_dir) and is_binary(key) and is_integer(max_bytes) and max_bytes > 0 do
    File.mkdir_p!(cache_dir)

    fname = filename_for(key, ext)
    final_path = Path.join(cache_dir, fname)

    # Atomic write: temp then rename
    tmp = Path.join(cache_dir, ".#{fname}.#{System.unique_integer([:positive])}.tmp")
    File.write!(tmp, data, [:binary])
    File.rename!(tmp, final_path)

    enforce_capacity(cache_dir, max_bytes)
    final_path
  end

  @doc """
  Returns the path for `key` if it exists, else `nil`.
  """
  def get_path(cache_dir, key, ext \\ @default_ext) do
    path = Path.join(cache_dir, filename_for(key, ext))
    if File.regular?(path), do: path, else: nil
  end

  @doc """
  Enforces the byte cap by deleting oldest files until total <= max_bytes.

  Concurrency: uses a **local ETS lock** per `cache_dir`. If another process on
  this node is evicting, this call will be a no-op (fast exit).
  """
  def enforce_capacity(cache_dir, max_bytes) when is_integer(max_bytes) and max_bytes > 0 do
    ensure_lock_table!()

    lock_id = {:image_cache_lock, Path.expand(cache_dir)}

    case try_acquire_lock(lock_id) do
      :acquired ->
        try do
          do_enforce_capacity(cache_dir, max_bytes)
        after
          release_lock(lock_id)
        end

      :busy ->
        # Someone else is evicting. Skip—best effort. Next write will re-check.
        :ok
    end
  end

  ## ——— Internal: eviction + helpers ———

  defp do_enforce_capacity(cache_dir, max_bytes) do
    files =
      cache_dir
      |> list_cache_files()
      |> Enum.map(&file_info/1)
      |> Enum.reject(&is_nil/1)

    total = Enum.reduce(files, 0, fn %{size: s}, acc -> acc + s end)

    if total <= max_bytes do
      :ok
    else
      evict_until(sorted_oldest_first(files), total, max_bytes)
    end
  end

  defp evict_until([], _total, _max), do: :ok

  defp evict_until([%{path: path, size: size} | rest], total, max) when total > max do
    # Ignore errors—another process may have already removed it
    _ = File.rm(path)
    evict_until(rest, max(total - size, 0), max)
  end

  defp evict_until(_files, _total, _max), do: :ok

  defp sorted_oldest_first(files), do: Enum.sort_by(files, & &1.mtime_posix)

  defp filename_for(key, ext) do
    # urlsafe base64 of sha256(key) → short, filesystem-safe; add an ext for convenience
    hash = :crypto.hash(:sha256, key) |> Base.url_encode64(padding: false)
    "#{hash}.#{ext}"
  end

  defp list_cache_files(dir) do
    case File.ls(dir) do
      {:ok, names} ->
        names
        # ignore temp/hidden
        |> Enum.reject(&String.starts_with?(&1, "."))
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.filter(&File.regular?/1)

      _ ->
        []
    end
  end

  defp file_info(path) do
    # Use posix seconds for stable comparisons
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{size: size, mtime: mtime}} -> %{path: path, size: size, mtime_posix: mtime}
      _ -> nil
    end
  end

  ## ——— Local ETS lock (per-node) ———
  ##
  ## - Non-blocking: first caller acquires; others see :busy and skip eviction.
  ## - Crash-safety: if the process dies, the entry is GC'd when the ETS table is deleted
  ##   on shutdown. For long-running nodes, that's fine because we always release in `after`.
  ## - If you prefer blocking, see the commented “blocking retry” helper below.

  defp ensure_lock_table!() do
    case :ets.info(@lock_table) do
      :undefined ->
        # public for simplicity; protected would also be fine
        :ets.new(@lock_table, [:named_table, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp try_acquire_lock(lock_id) do
    # Insert new row with owner pid; if it already exists, we’re busy.
    # {lock_id, owner_pid}
    case :ets.insert_new(@lock_table, {lock_id, self()}) do
      true -> :acquired
      false -> :busy
    end
  end

  defp release_lock(lock_id), do: :ets.delete(@lock_table, lock_id)

  # ——— Optional: blocking retry (use instead of `:busy` fast-exit) ———
  # defp acquire_lock_with_retry(lock_id, timeout_ms \\ 2_000) do
  #   started = System.monotonic_time(:millisecond)
  #   do_acquire(lock_id, started, timeout_ms)
  # end
  #
  # defp do_acquire(lock_id, started, timeout_ms) do
  #   case try_acquire_lock(lock_id) do
  #     :acquired -> :acquired
  #     :busy ->
  #       if System.monotonic_time(:millisecond) - started > timeout_ms do
  #         :busy
  #       else
  #         Process.sleep(25)
  #         do_acquire(lock_id, started, timeout_ms)
  #       end
  #   end
  # end
end
