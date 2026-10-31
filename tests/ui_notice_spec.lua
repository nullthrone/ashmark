local wow = require("tests.helpers.wow")

describe("UI Notice", function()
  local ns, alpha

  -- Records the settings of the notice's Alpha animation, which the mock frames would swallow.
  local function recordAnimation()
    local create = CreateFrame
    wow.stub("CreateFrame", function(kind, name, ...)
      local frame = create(kind, name, ...)
      if name == "AshmarkNoticeFrame" then
        frame.CreateAnimationGroup = function(owner)
          local group = wow.newFrame("AnimationGroup", nil, owner)
          group.CreateAnimation = function(_, animationType)
            local animation = wow.newFrame("Animation", nil, group)
            alpha = { type = animationType }
            for _, method in ipairs({ "SetFromAlpha", "SetToAlpha", "SetStartDelay", "SetDuration" }) do
              animation[method] = function(_, value) alpha[method] = value end
            end
            return animation
          end
          return group
        end
      end
      return frame
    end)
  end

  before_each(function()
    wow.reset()
    alpha = nil
    recordAnimation()
    ns = wow.load({ "UI/Notice.lua" })
    wow.login()
  end)

  after_each(function()
    assert.same({}, wow.errors)
  end)

  it("shows one huge line at the top of the screen in the system chat colour", function()
    ns.UI.Notice:Show("Chapter II closes · Desolace")
    local frame = _G.AshmarkNoticeFrame
    assert.is_true(frame:IsShown())
    assert.equal(1, frame:GetAlpha())
    assert.same({ "TOP", UIParent, "TOP", 0, -200 }, { frame:GetPoint(1) })
    assert.equal("GameFontNormalHuge", frame.Text.__template)
    assert.equal("Chapter II closes · Desolace", frame.Text:GetText())
    local info = ChatTypeInfo.SYSTEM
    assert.same({ info.r, info.g, info.b }, { frame.Text:GetTextColor() })
  end)

  it("holds for 3 s and fades out over 1 s", function()
    ns.UI.Notice:Show("x")
    assert.same({ type = "Alpha", SetFromAlpha = 1, SetToAlpha = 0, SetStartDelay = 3, SetDuration = 1 }, alpha)
  end)

  it("hides when the fade ends, after combat if it ends in combat", function()
    ns.UI.Notice:Show("x")
    local frame = _G.AshmarkNoticeFrame
    wow.combat(true)
    wow.script(frame.Fade, "OnFinished")
    assert.is_true(frame:IsShown())
    wow.combat(false)
    assert.is_false(frame:IsShown())
  end)

  it("keeps a notice shown after an earlier fade ended in combat", function()
    ns.UI.Notice:Show("first")
    local frame = _G.AshmarkNoticeFrame
    local playing = false
    frame.Fade.Play = function() playing = true end
    frame.Fade.Stop = function() playing = false end
    frame.Fade.IsPlaying = function() return playing end
    wow.combat(true)
    ns.UI.Notice:Show("second")
    wow.script(frame.Fade, "OnFinished")
    wow.combat(false)
    assert.is_true(frame:IsShown())
    assert.equal("second", frame.Text:GetText())
  end)

  it("waits for the end of combat and shows only the latest notice", function()
    wow.combat(true)
    ns.UI.Notice:Show("first")
    ns.UI.Notice:Show("second")
    assert.is_nil(_G.AshmarkNoticeFrame)
    wow.combat(false)
    assert.equal("second", _G.AshmarkNoticeFrame.Text:GetText())
  end)

  it("restarts for a new notice", function()
    ns.UI.Notice:Show("first")
    local frame = _G.AshmarkNoticeFrame
    frame:SetAlpha(0.2)
    ns.UI.Notice:Show("second")
    assert.equal(frame, _G.AshmarkNoticeFrame)
    assert.equal(1, frame:GetAlpha())
    assert.equal("second", frame.Text:GetText())
  end)

  it("ignores empty and secret text", function()
    ns.UI.Notice:Show("")
    ns.UI.Notice:Show(nil)
    ns.UI.Notice:Show(wow.secret("x"))
    assert.is_nil(_G.AshmarkNoticeFrame)
  end)
end)
