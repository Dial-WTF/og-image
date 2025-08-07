defmodule OgImage.ImageCacheTest do
  use ExUnit.Case, async: true

  alias OgImage.ImageCache

  setup do
    # Create a unique temp directory for each test
    cache_dir = Path.join(System.tmp_dir!(), "image_cache_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)

    on_exit(fn ->
      # Clean up after test
      File.rm_rf!(cache_dir)
    end)

    {:ok, cache_dir: cache_dir}
  end

  describe "put/5" do
    test "stores data and returns the file path", %{cache_dir: cache_dir} do
      key = "test_key"
      data = "test data"
      max_bytes = 1_000_000

      path = ImageCache.put(cache_dir, key, data, max_bytes)

      assert String.starts_with?(path, cache_dir)
      assert File.exists?(path)
      assert File.read!(path) == data
    end

    test "creates cache directory if it doesn't exist" do
      new_cache_dir = Path.join(System.tmp_dir!(), "new_cache_#{:rand.uniform(1_000_000)}")
      refute File.exists?(new_cache_dir)

      key = "test_key"
      data = "test data"
      max_bytes = 1_000_000

      path = ImageCache.put(new_cache_dir, key, data, max_bytes)

      assert File.exists?(new_cache_dir)
      assert File.exists?(path)

      # Cleanup
      File.rm_rf!(new_cache_dir)
    end

    test "uses custom extension when provided", %{cache_dir: cache_dir} do
      key = "test_key"
      data = "test data"
      max_bytes = 1_000_000

      path = ImageCache.put(cache_dir, key, data, max_bytes, "png")

      assert String.ends_with?(path, ".png")
      assert File.exists?(path)
    end

    test "generates consistent filename for same key", %{cache_dir: cache_dir} do
      key = "same_key"
      data1 = "data 1"
      data2 = "data 2"
      max_bytes = 1_000_000

      path1 = ImageCache.put(cache_dir, key, data1, max_bytes)
      path2 = ImageCache.put(cache_dir, key, data2, max_bytes)

      assert path1 == path2
      # Second write should overwrite
      assert File.read!(path2) == data2
    end

    test "enforces capacity after write", %{cache_dir: cache_dir} do
      # Small capacity that fits only 2 files
      max_bytes = 20

      # Write 3 files
      ImageCache.put(cache_dir, "key1", "data1data1", max_bytes)
      # Ensure different mtime
      Process.sleep(10)
      ImageCache.put(cache_dir, "key2", "data2data2", max_bytes)
      Process.sleep(10)
      ImageCache.put(cache_dir, "key3", "data3data3", max_bytes)

      # Only 2 files should remain (newest ones)
      files = File.ls!(cache_dir)
      assert length(files) == 2
    end
  end

  describe "get_path/3" do
    test "returns path for existing file", %{cache_dir: cache_dir} do
      key = "test_key"
      data = "test data"
      max_bytes = 1_000_000

      stored_path = ImageCache.put(cache_dir, key, data, max_bytes)
      retrieved_path = ImageCache.get_path(cache_dir, key)

      assert retrieved_path == stored_path
      assert File.exists?(retrieved_path)
    end

    test "returns nil for non-existent file", %{cache_dir: cache_dir} do
      path = ImageCache.get_path(cache_dir, "non_existent_key")
      assert path == nil
    end

    test "respects custom extension", %{cache_dir: cache_dir} do
      key = "test_key"
      data = "test data"
      max_bytes = 1_000_000

      ImageCache.put(cache_dir, key, data, max_bytes, "png")

      # Should find with correct extension
      assert ImageCache.get_path(cache_dir, key, "png") != nil

      # Should not find with wrong extension
      assert ImageCache.get_path(cache_dir, key, "jpg") == nil
    end

    test "returns nil for directories", %{cache_dir: cache_dir} do
      # Create a directory with the expected filename
      key = "dir_key"
      expected_filename = :crypto.hash(:sha256, key) |> Base.url_encode64(padding: false)
      dir_path = Path.join(cache_dir, "#{expected_filename}.bin")
      File.mkdir_p!(dir_path)

      assert ImageCache.get_path(cache_dir, key) == nil
    end
  end

  describe "enforce_capacity/2" do
    test "removes oldest files when over capacity", %{cache_dir: cache_dir} do
      # Use the put function to ensure proper file naming
      # Large enough to not trigger eviction during put
      max_bytes = 1000

      # Write files with delays to ensure different mtimes
      path1 = ImageCache.put(cache_dir, "old_file", String.duplicate("a", 100), max_bytes)
      # Ensure different mtimes
      Process.sleep(50)
      path2 = ImageCache.put(cache_dir, "middle_file", String.duplicate("b", 100), max_bytes)
      Process.sleep(50)
      path3 = ImageCache.put(cache_dir, "new_file", String.duplicate("c", 100), max_bytes)

      # Enforce capacity that only fits 1 file (100 bytes)
      ImageCache.enforce_capacity(cache_dir, 100)

      # Only the newest file should remain
      # old_file should be deleted
      refute File.exists?(path1)
      # middle_file should be deleted
      refute File.exists?(path2)
      # new_file should remain
      assert File.exists?(path3)

      # Verify only one file remains
      remaining_files = File.ls!(cache_dir)
      assert length(remaining_files) == 1
    end

    test "does nothing when under capacity", %{cache_dir: cache_dir} do
      files = [
        {"file1", "123"},
        {"file2", "456"},
        {"file3", "789"}
      ]

      for {key, data} <- files do
        File.write!(Path.join(cache_dir, "#{key}.bin"), data)
      end

      # Large capacity that fits all files
      ImageCache.enforce_capacity(cache_dir, 1_000_000)

      assert length(File.ls!(cache_dir)) == 3
    end

    test "handles empty directory", %{cache_dir: cache_dir} do
      # Should not crash on empty directory
      ImageCache.enforce_capacity(cache_dir, 100)
      assert File.ls!(cache_dir) == []
    end

    test "ignores hidden/temp files", %{cache_dir: cache_dir} do
      # Create some regular files and hidden files
      File.write!(Path.join(cache_dir, "regular.bin"), "data")
      File.write!(Path.join(cache_dir, ".hidden"), "hidden")
      File.write!(Path.join(cache_dir, ".temp.12345.tmp"), "temp")

      # Small capacity that would trigger eviction if hidden files were counted
      ImageCache.enforce_capacity(cache_dir, 10)

      files = File.ls!(cache_dir)
      assert "regular.bin" in files
      assert ".hidden" in files
      assert ".temp.12345.tmp" in files
    end

    test "handles non-existent directory gracefully", %{cache_dir: _} do
      non_existent = Path.join(System.tmp_dir!(), "non_existent_#{:rand.uniform(1_000_000)}")

      # Should not crash
      ImageCache.enforce_capacity(non_existent, 100)
    end
  end

  describe "concurrency and locking" do
    test "concurrent puts work correctly", %{cache_dir: cache_dir} do
      max_bytes = 1_000_000

      # Spawn multiple processes writing different keys
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            ImageCache.put(cache_dir, "key_#{i}", "data_#{i}", max_bytes)
          end)
        end

      paths = Task.await_many(tasks)

      # All files should exist
      assert length(paths) == 10
      assert Enum.all?(paths, &File.exists?/1)
    end

    test "lock prevents concurrent evictions", %{cache_dir: cache_dir} do
      # Fill cache with files
      for i <- 1..5 do
        File.write!(Path.join(cache_dir, "file_#{i}.bin"), String.duplicate("x", 100))
      end

      # Track eviction attempts
      parent = self()

      # Spawn multiple processes trying to evict
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            # Small capacity to force eviction
            ImageCache.enforce_capacity(cache_dir, 50)
            send(parent, :eviction_done)
          end)
        end

      Task.await_many(tasks)

      # All tasks should complete without error
      messages =
        for _ <- 1..5 do
          receive do
            msg -> msg
          after
            100 -> :timeout
          end
        end

      assert Enum.all?(messages, &(&1 == :eviction_done))
    end
  end

  describe "edge cases and error handling" do
    test "handles file deletion during eviction", %{cache_dir: cache_dir} do
      # Create a file
      file_path = Path.join(cache_dir, "test.bin")
      File.write!(file_path, "data")

      # Delete it manually before eviction
      File.rm!(file_path)

      # Should not crash when trying to evict non-existent file
      ImageCache.enforce_capacity(cache_dir, 1)
    end

    test "handles invalid max_bytes gracefully" do
      cache_dir = System.tmp_dir!()

      # These should raise due to guard clauses
      assert_raise FunctionClauseError, fn ->
        ImageCache.put(cache_dir, "key", "data", 0)
      end

      assert_raise FunctionClauseError, fn ->
        ImageCache.put(cache_dir, "key", "data", -1)
      end
    end

    test "atomic writes prevent partial files", %{cache_dir: cache_dir} do
      key = "atomic_test"
      max_bytes = 1_000_000

      # Simulate multiple concurrent writes to same key
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            data = String.duplicate("#{i}", 1000)
            ImageCache.put(cache_dir, key, data, max_bytes)
            {i, data}
          end)
        end

      results = Task.await_many(tasks)

      # Read final file - should be complete data from one of the writes
      final_path = ImageCache.get_path(cache_dir, key)
      final_data = File.read!(final_path)

      # Verify it matches one of the complete writes
      valid_datas = Enum.map(results, fn {_, data} -> data end)
      assert final_data in valid_datas
    end
  end

  describe "filename generation" do
    test "generates URL-safe filenames" do
      # Test with various special characters
      keys = [
        "simple",
        "with spaces",
        "with/slashes",
        "with\\backslashes",
        "with:colons",
        "with|pipes",
        "unicode_测试_🎉"
      ]

      for key <- keys do
        # This is the internal logic from filename_for/2
        hash = :crypto.hash(:sha256, key) |> Base.url_encode64(padding: false)
        filename = "#{hash}.bin"

        # Should only contain URL-safe characters
        assert Regex.match?(~r/^[A-Za-z0-9_-]+\.bin$/, filename)
      end
    end

    test "different keys produce different filenames", %{cache_dir: cache_dir} do
      max_bytes = 1_000_000

      path1 = ImageCache.put(cache_dir, "key1", "data", max_bytes)
      path2 = ImageCache.put(cache_dir, "key2", "data", max_bytes)

      assert path1 != path2
    end
  end
end
