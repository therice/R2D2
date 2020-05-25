local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local logging
describe("LibLogging", function()
    setup(function()
        _G.LibLogging_Testing = true
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        logging, _ = LibStub('LibLogging-1.0')
    end)
    teardown(function()
        _G.LibLogging_Testing = nil
        After()
    end)
    describe("logging levels", function()
        it("define thresholds", function()
            local min =  logging:GetMinThreshold()
            local max =  logging:GetMaxThreshold()

            for key, value in pairs(logging.Level) do
                local threshold = logging:GetThreshold(value)
                assert.is_number(threshold)
                assert(threshold >= min,format("%s(%s) not greater than min threshold %s", key, threshold, min))
                assert(threshold <= max,format("%s(%s) not less than max threshold %s", key, threshold, max))
            end
        end)
    end)
    --[[
    lib.Level = {
    Disabled    = "Disabled",
    Trace       = "Trace",
    Debug       = "Debug",
    Info        = "Info",
    Warn        = "Warn",
    Error       = "Error",
    Fatal       = "Fatal"
}
    --]]
    describe("root threshold", function()
        it("can be specified", function()
            logging:SetRootThreshold(logging.Level.Info)
            assert(logging:GetRootThreshold() == logging:GetThreshold(logging.Level.Info))
            assert(not logging:IsEnabledFor(logging.Level.Trace))
            assert(not logging:IsEnabledFor(logging.Level.Debug))
            assert(logging:IsEnabledFor(logging.Level.Info))
            assert(logging:IsEnabledFor(logging.Level.Warn))
            assert(logging:IsEnabledFor(logging.Level.Error))
            assert(logging:IsEnabledFor(logging.Level.Fatal))
            logging:Enable()
            assert(logging:GetRootThreshold()== logging:GetThreshold(logging.Level.Debug))
            assert(not logging:IsEnabledFor(logging.Level.Trace))
            assert(logging:IsEnabledFor(logging.Level.Debug))
            assert(logging:IsEnabledFor(logging.Level.Info))
            assert(logging:IsEnabledFor(logging.Level.Warn))
            assert(logging:IsEnabledFor(logging.Level.Error))
            assert(logging:IsEnabledFor(logging.Level.Fatal))
            logging:Disable()
            assert(logging:GetRootThreshold()== logging:GetThreshold(logging.Level.Disabled))
            assert(not logging:IsEnabledFor(logging.Level.Trace))
            assert(not logging:IsEnabledFor(logging.Level.Debug))
            assert(not logging:IsEnabledFor(logging.Level.Info))
            assert(not logging:IsEnabledFor(logging.Level.Warn))
            assert(not logging:IsEnabledFor(logging.Level.Error))
            assert(not  logging:IsEnabledFor(logging.Level.Fatal))
        end)
    end)
    describe("write output to", function()
        it("specified handler", function()
            local logging_output = ""
            local CaptureOutput = function(msg)
                logging_output = msg
            end

            logging:SetRootThreshold(logging.Level.Debug)
            logging:SetWriter(CaptureOutput)
            logging:Log(logging.Level.Info, "InfoTest")
            assert.matches("INFO.*(LibLoggingTest.lua.*): InfoTest",logging_output)
            logging_output = ""
            logging:Debug("DebugTest")
            assert.matches("DEBUG.*(LibLoggingTest.lua.*): DebugTest",logging_output)
            logging_output = ""
            logging:Trace("TraceTest")
            assert(logging_output == '')
            logging:ResetWriter()
        end)
    end)
end)