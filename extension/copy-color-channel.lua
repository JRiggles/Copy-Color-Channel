--[[
MIT LICENSE
Copyright © 2024 John Riggles [sudo_whoami]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- stop complaining about unknown Aseprite API methods
---@diagnostic disable: undefined-global
-- ignore dialogs which are defined with local names for readablity, but may be unused
---@diagnostic disable: unused-local

local preferences = {} -- create a global table to store extension preferences

local function checkActiveElements()
  if not app.sprite then
    app.alert("No active image. Please open an image or create a new one.")
    return false
  elseif not app.layer then
    app.alert("No selected layer!")
    return false
  elseif not app.cel then
    app.alert("No selected cel!")
    return false
  elseif not app.cel.image.colorMode == ColorMode.RGB then
    app.alert("This script only works in RGB Color Mode!")
    return false
  end
  return true -- all checks passed
end

app.transaction(
  "copy color channel",
  function ()
    function CopyColor(channel, keepAlpha)
      local cel = app.cel
      local celCopy = cel.image:clone()
      app.command.duplicateLayer(cel.layer)
      local layer = cel.layer
      local layerName = layer.name
      layer.isVisible = true

      for pixel in celCopy:pixels() do
        -- map channel names to color components
        local channelColors = {
          ["Red"] =     { r = 1, g = 0, b = 0 },
          ["Green"] =   { r = 0, g = 1, b = 0 },
          ["Blue"] =    { r = 0, g = 0, b = 1 },
          ["Cyan"] =    { r = 0, g = 1, b = 1 },
          ["Magenta"] = { r = 1, g = 0, b = 1 },
          ["Yellow"] =  { r = 1, g = 1, b = 0 }
        }
        local chA
          if keepAlpha then
            chA = app.pixelColor.rgbaA(pixel()) -- retain existing transparency value
          else
            chA = 1 -- override transparency value
          end
        -- get each pixel's current color channel values
        celCopy:drawPixel(pixel.x, pixel.y, Color {
            r = app.pixelColor.rgbaR(pixel()) * channelColors[channel].r,
            g = app.pixelColor.rgbaG(pixel()) * channelColors[channel].g,
            b = app.pixelColor.rgbaB(pixel()) * channelColors[channel].b,
            a = chA
        })
      end
      -- create a new layer with the selected color component
      app.layer.name = layerName .. ": " .. channel
      app.image:drawImage(celCopy)
    end
  end
)
local channelNames = { "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow" }

local function main()
  if not checkActiveElements() then
    return -- bail
  else
    local function createChannelButtons(dialog)
      for i, channel in ipairs(channelNames) do
        dialog:button {
          text = channel,
          onclick = function()
            CopyColor(channel, dialog.data.keepAlpha)
            dialog:close()
          end
        }
        if i % 3 == 0 and i < #channelNames then -- limit the buttons to 3 per row
          dialog:separator { text = "Composite Channels" }
        end
      end
    end

    local channelDlg = Dialog("Select a color component")
      :label { text = "Copies the chosen color component(s) of" }
      :newrow()
      :label { text = "the currently selected cel to a new layer" }
      channelDlg:button { text = "Copy All Channels", onclick = function ()
          for i, channel in ipairs(channelNames) do
            local currentLayer = app.layer
            CopyColor(channel, channelDlg.data.keepAlpha)
            app.layer = currentLayer
            channelDlg:close()
          end
        end
      }
      :newrow()
      :separator { text = "Primary Channels" }
      :newrow()
      createChannelButtons(channelDlg) -- add button for each color channel
      channelDlg:newrow()
      :check { id = "keepAlpha", text = "Retain transparency", selected = true }
      :show()
  end
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin) -- initialize extension
  preferences = plugin.preferences -- update preferences global with plugin.preferences values


  -- add "Copy Color Channel" command to palette options menu
  plugin:newCommand {
      id = "CopyColorChannel",
      title = "Copy Color Channel...",
      group = "sprite_color",
      onclick = main -- run main function
  }
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
  plugin.preferences = preferences -- save preferences
  return nil
end
