local helpers = require("ink_test_helpers")

describe("collections.data load", function()
  local coll, path, restore_dir, restore_notify

  before_each(function()
    local dir
    dir, restore_dir = helpers.use_temp_data_dir()
    _, restore_notify = helpers.capture_notify()

    path = dir .. "/collections.json"
    coll = require("ink.collections.data")
    coll.invalidate_cache()
  end)

  after_each(function()
    restore_notify()
    restore_dir()
  end)

  it("returns defaults when there is no file", function()
    local d = coll.load()
    assert.are.equal(1, d.version)
    assert.are.equal(0, #d.collections)
  end)

  it("loads a valid file", function()
    helpers.write(path, vim.json.encode({ version = 2, collections = { { id = "a" } } }))

    local d = coll.load()
    assert.are.equal(2, d.version)
    assert.are.equal("a", d.collections[1].id)
  end)

  it("fills in missing fields", function()
    helpers.write(path, "{}")

    local d = coll.load()
    assert.are.equal(1, d.version)
    assert.are.equal("table", type(d.collections))
  end)

  it("treats a null root as invalid", function()
    helpers.write(path, "null")

    local d = coll.load()
    assert.are.equal(1, d.version)
    assert.are.equal(0, #d.collections)
  end)

  describe("corrupted file", function()
    it("recovers from the .backup copy and writes it back", function()
      helpers.write(path, "{ not json")
      helpers.write(path .. ".backup", vim.json.encode({ version = 1, collections = { { id = "b" } } }))

      local d = coll.load()
      assert.are.equal("b", d.collections[1].id)
      assert.are.equal(1, vim.fn.filereadable(path))

      -- A second load must see the recovered data
      assert.are.equal("b", coll.load().collections[1].id)
    end)

    it("recovers from the newest timestamped backup", function()
      helpers.write(path, "{ not json")
      helpers.write(path .. ".backup.100", vim.json.encode({ version = 1, collections = { { id = "old" } } }))
      helpers.write(path .. ".backup.200", vim.json.encode({ version = 1, collections = { { id = "new" } } }))

      local d = coll.load()
      assert.are.equal("new", d.collections[1].id)
    end)

    it("returns defaults when there is no backup", function()
      helpers.write(path, "{ not json")

      local d = coll.load()
      assert.are.equal(1, d.version)
      assert.are.equal(0, #d.collections)
    end)

    it("preserves the corrupted content as a timestamped backup", function()
      helpers.write(path, "{ not json")
      coll.load()

      local backups = vim.fn.glob(path .. ".backup.*", false, true)
      assert.are.equal(1, #backups)
    end)
  end)
end)
