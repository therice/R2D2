local pl = require('pl.path')
local this = pl.abspath(pl.abspath('.') .. '/' .. debug.getinfo(1).source:match("@(.*)$"))

local Util, Logging, Compression
local TestValue = "12123123412345123456123456712345678123456789"

describe("LibUtil", function()
    setup(function()
        _G.LibUtil_Testing = true
        loadfile(pl.abspath(pl.dirname(this) .. '/../../../Test/TestSetup.lua'))(this, {})
        Util, _ = LibStub('LibUtil-1.1')
        Compression = Util.Compression
        Logging = R2D2.Libs.Logging
        Logging:SetRootThreshold(Logging.Level.Trace)
    end)
    teardown(function()
        _G.LibUtil_Testing = nil
    end)
    describe("Compression", function()
        it("handles encoding/decoding ", function()
            for _, encoder in pairs(Compression.Encoders()) do
                local encoded = encoder:encode(TestValue)
                assert(encoder:decode(encoded) == TestValue)
            end
        end)
        --it("handles mixed encoding", function()
        --    local c1 = Util.Compression.Compressors[2] -- LibCompressCompressor
        --    local c2 = Util.Compression.Compressors[3] -- LibDeflateCompressor
        --    local a1 = c1:compress(TestValue)
        --    local a2 = c2:compress(TestValue)
        --    print('LibCompressCompressor(false) ' .. a1)
        --    print('LibDeflateCompressor(false) ' .. a2)
        --    local r1 = c1:compress(TestValue, true)
        --    local r2 = c2:compress(TestValue, true)
        --    print('LibCompressCompressor(true) ' .. r1)
        --    print('LibDeflateCompressor(true) ' .. r2)
        --    local e1 = Util.Compression.Encoders[2] -- LibCompressEncoder
        --    local e2 = Util.Compression.Encoders[3] -- LibDeflateEncoder
        --
        --    print('LibCompressEncoder:decode(LibDeflateCompressor) '  .. e1:decode(r2 .. '\000'))
        --    print('LibCompressEncoder:decode(LibCompressCompressor) '  .. e1:decode(r1 .. '\000'))
        --    print('LibDeflateEncoder:decode(LibCompressEncoder) ' .. e2:decode(r1))
        --    print('LibDeflateEncoder:decode(LibDeflateCompressor) ' .. e2:decode(r2))
        --end)
        it("handles compression", function()
            for _, compressor in pairs(Compression.Compressors()) do
                local compressed = compressor:compress(TestValue)
                compressed = compressor:compress(TestValue, true)
            end
        end)
        it("handles decompression", function()
            for _, compressor in pairs(Compression.Compressors()) do
                local compressed = compressor:compress(TestValue)
                local decompressed = compressor:decompress(compressed)
                assert(TestValue == decompressed)
            end
        end)
        it("handles decompression with encoding", function()
            for _, compressor in pairs(Compression.Compressors()) do
                local compressed = compressor:compress(TestValue, false)
                local decompressed = compressor:decompress(compressed, false)
                assert(TestValue == decompressed)
            end
        end)
        it("handles selecting specific encoders", function()
            local C = Compression.Compressors()
            local compressors = Compression.GetCompressors(Compression.CompressorType.LibDeflate)
            assert(#compressors == 1)
            assert(compressors[1] == C[Compression.CompressorType.LibDeflate])
            compressors = Compression.GetCompressors(
                    Compression.CompressorType.LibCompress,
                    Compression.CompressorType.LibDeflate,
                    Compression.CompressorType.LibCompressNoOp
            )
            assert(#compressors == 3)
            assert(compressors[1] == C[Compression.CompressorType.LibCompress])
            assert(compressors[2] == C[Compression.CompressorType.LibDeflate])
            assert(compressors[3] == C[Compression.CompressorType.LibCompressNoOp])
        end)
        --it("handles mixing compression", function()
        --    local c1 = Util.Compression.Compressors[2]
        --    local c2 = Util.Compression.Compressors[3]
        --    local compressed = c1:compress(TestValue, false)
        --    local decompressed = c2:decompress(compressed, false)
        --    print(decompressed)
        --end)
    end)
end)