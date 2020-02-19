local pl = require('pl.path')


local logging
describe("LibLogging", function()
    setup(function()
        _G.LibLogging_Testing = true
        loadfile(pl.abspath(pl.abspath('.') .. '/../../../Test/TestSetup.lua'))()
        logging, _ = LibStub('LibLogging-1.0')
    end)
    teardown(function()
        _G.LibLogging_Testing = nil
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
    describe("root threshold", function()
        it("can be specified", function()
            logging:SetRootThreshold(logging.Level.Info)
            assert(logging:GetRootThreshold() == logging:GetThreshold(logging.Level.Info))
            logging:Enable()
            assert(logging:GetRootThreshold()== logging:GetThreshold(logging.Level.Debug))
            logging:Disable()
            assert(logging:GetRootThreshold()== logging:GetThreshold(logging.Level.Disabled))
        end)
    end)
    describe("write output to", function()
        it("specified handler", function()
            local logging_output
            local CaptureOutput = function(msg)
                logging_output = msg
            end

            logging:SetWriter(CaptureOutput)
            logging:SetRootThreshold(logging.Level.Info)
            logging:Log(logging.Level.Info, "InfoTest")
            assert.matches("INFO.*(LibLoggingTest.lua.*): InfoTest",logging_output)
            logging:Debug("DebugTest")
            assert.matches("DEBUG.*(LibLoggingTest.lua.*): DebugTest",logging_output)
            logging:ResetWriter()
        end)
    end)
end)