#!/usr/bin/env lua

addonData = { ["version"] = "1.0",
}

require "wowTest"

test.outFileName = "testOut.xml"

wowCron_Frame = CreateFrame()

-- require the file to test
package.path = "../src/?.lua;'" .. package.path
require "Hitlist"

function test.before()
end
function test.after()
end


test.run()
