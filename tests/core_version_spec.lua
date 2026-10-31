local wow = require("tests.helpers.wow")

describe("Core version", function()
  before_each(function()
    wow.reset()
  end)

  it("reads the release tag the packager wrote into ## Version", function()
    wow.data.metadata.Version = "v1.2.0"
    assert.equal("v1.2.0", wow.load().version)
  end)

  it("reads dev from a copy run from the source, whose TOC still holds the packager's token", function()
    wow.data.metadata.Version = "@project-version@"
    assert.equal("dev", wow.load().version)
  end)

  it("reads dev when the TOC names no version", function()
    wow.data.metadata.Version = nil
    assert.equal("dev", wow.load().version)
    wow.reset()
    wow.data.metadata.Version = ""
    assert.equal("dev", wow.load().version)
  end)
end)
