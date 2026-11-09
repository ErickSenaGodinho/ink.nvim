local helpers = require("ink_test_helpers")

describe("health", function()
  local dir, restore_dir

  before_each(function()
    dir, restore_dir = helpers.use_temp_data_dir()
  end)

  after_each(function()
    restore_dir()
  end)

  local function write_all(content)
    for _, name in ipairs({ "library.json", "collections.json", "related.json" }) do
      helpers.write(dir .. "/" .. name, content)
    end
  end

  it("runs with no data files", function()
    assert.has_no.errors(function()
      require("ink.health").check()
    end)
  end)

  it("does not crash when every JSON root is null", function()
    write_all("null")

    assert.has_no.errors(function()
      require("ink.health").check()
    end)
  end)

  it("does not crash when every JSON root is a scalar", function()
    write_all("42")

    assert.has_no.errors(function()
      require("ink.health").check()
    end)
  end)

  it("does not crash on corrupted JSON", function()
    write_all("{ not json")

    assert.has_no.errors(function()
      require("ink.health").check()
    end)
  end)

  it("does not modify or delete corrupted files", function()
    write_all("{ not json")
    require("ink.health").check()

    for _, name in ipairs({ "library.json", "collections.json", "related.json" }) do
      assert.are.equal(1, vim.fn.filereadable(dir .. "/" .. name))
    end
    assert.are.equal(0, #vim.fn.glob(dir .. "/*.backup.*", false, true))
  end)
end)
