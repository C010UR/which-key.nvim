local Mappings = require("which-key.mappings")
local Node = require("which-key.node")
local View = require("which-key.view")

before_each(function()
  Mappings.notifs = {}
end)

describe("category fields", function()
  it("inherits category to children", function()
    local result = Mappings.parse({
      {
        category = "Files",
        { "<leader>a", "a", desc = "Alpha" },
        { "<leader>b", "b", desc = "Beta", category = "Git" },
      },
    })
    local by_lhs = {}
    for _, mapping in ipairs(result) do
      by_lhs[mapping.lhs] = mapping
    end
    assert.equal("Files", by_lhs["<leader>a"].category)
    assert.equal("Git", by_lhs["<leader>b"].category)
  end)

  it("parses order and category_order", function()
    local result = Mappings.parse({
      {
        "<leader>",
        group = "Leader",
        category_order = { "Files", "Git", "Other" },
      },
      { "<leader>a", "a", desc = "Alpha", category = "Files", order = 2 },
    })
    local leader = vim.tbl_filter(function(m)
      return m.lhs == "<leader>"
    end, result)[1]
    local alpha = vim.tbl_filter(function(m)
      return m.lhs == "<leader>a"
    end, result)[1]
    assert.same({ "Files", "Git", "Other" }, leader.category_order)
    assert.equal("Files", alpha.category)
    assert.equal(2, alpha.order)
  end)
end)

describe("categorize", function()
  ---@param key string
  ---@param category? string
  ---@return wk.Item
  local function item(key, category)
    return {
      key = key,
      raw_key = key,
      desc = key,
      category = category,
    }
  end

  ---@param category_order? string[]
  ---@return wk.Node
  local function group_node(category_order)
    local node = Node.new()
    if category_order then
      node.mapping = { category_order = category_order }
    end
    return node
  end

  ---@param sections wk.Section[]
  ---@return string[]
  local function section_names(sections)
    return vim.tbl_map(function(section)
      return section.name
    end, sections)
  end

  it("uses category_order from the group node", function()
    local sections = View.categorize({
      item("a", "Git"),
      item("b", "Files"),
      item("c", "Search"),
    }, group_node({ "Files", "Git", "Search", "Other" }))
    assert.same({ "Files", "Git", "Search" }, section_names(sections))
  end)

  it("puts uncategorized mappings in the default category", function()
    local sections = View.categorize({
      item("a", "Files"),
      item("b"),
    }, group_node({ "Files", "Other" }))
    assert.same({ "Files", "Other" }, section_names(sections))
    assert.equal(1, #sections[2].items)
    assert.equal("b", sections[2].items[1].key)
  end)

  it("falls back to alphabetical order with default last", function()
    local sections = View.categorize({
      item("a", "Zebra"),
      item("b", "Alpha"),
      item("c"),
    }, group_node())
    assert.same({ "Alpha", "Zebra", "Other" }, section_names(sections))
  end)

  it("appends unknown categories after category_order", function()
    local sections = View.categorize({
      item("a", "Extra"),
      item("b", "Files"),
    }, group_node({ "Files" }))
    assert.same({ "Files", "Extra" }, section_names(sections))
  end)
end)

describe("sort and separator", function()
  it("sorts by order within a category", function()
    local items = {
      { key = "b", raw_key = "b", desc = "b", order = 2 },
      { key = "a", raw_key = "a", desc = "a", order = 1 },
    }
    View.sort(items, { "order" })
    assert.same({ "a", "b" }, vim.tbl_map(function(item)
      return item.key
    end, items))
  end)

  it("formats category separators", function()
    local segments = View.category_separator("Search", 16)
    assert.equal(16, vim.fn.strdisplaywidth(segments[1].str .. segments[2].str .. segments[3].str))
    assert.equal("─", segments[1].str)
    assert.equal(" Search ", segments[2].str)
    assert.equal("───────", segments[3].str)
    assert.equal("WhichKeyCategory", segments[2].hl)
  end)
end)
