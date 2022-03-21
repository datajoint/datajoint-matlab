classdef TestBlob < Prep
    methods (Test)
        function  TestBlob_test32BitRead(testCase)
            st = dbstack;
            disp(['---------------' st(1).name '---------------']);
            value = ['6D596D005302000000010000000100000004000000686974730073696465730074' ...
                '61736B73007374616765004D00000041020000000100000007000000060000000000000' ...
                '0000000000000F8FF000000000000F03F000000000000F03F0000000000000000000000' ...
                '000000F03F0000000000000000000000000000F8FF23000000410200000001000000070' ...
                '0000004000000000000006C006C006C006C00720072006C002300000041020000000100' ...
                '00000700000004000000000000006400640064006400640064006400250000004102000' ...
                '0000100000008000000040000000000000053007400610067006500200031003000'];
            hexstring = value';
            reshapedString = reshape(hexstring,2,length(value)/2);
            hexMtx = reshapedString.';
            decMtx = hex2dec(hexMtx);
            packed = uint8(decMtx);

            data = struct;
            data.stage = 'Stage 10';
            data.tasks = 'ddddddd';
            data.sides = 'llllrrl';
            data.hits = [NaN,1,1,0,1,0,NaN];

            dj.config('use_32bit_dims', true);
            unpacked = mym('deserialize', packed);
            dj.config('use_32bit_dims', false);

            testCase.verifyEqual(unpacked, data);
        end
    end
end