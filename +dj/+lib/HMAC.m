function hash = HMAC(key,message,method)
    % Copyright (c) 2014, Peter Grunnet Wang
    % All rights reserved.

    % Redistribution and use in source and binary forms, with or without
    % modification, are permitted provided that the following conditions are met:

    % * Redistributions of source code must retain the above copyright notice, this
    % list of conditions and the following disclaimer.

    % * Redistributions in binary form must reproduce the above copyright notice,
    % this list of conditions and the following disclaimer in the documentation
    % and/or other materials provided with the distribution
    % * Neither the name of  nor the names of its
    % contributors may be used to endorse or promote products derived from this
    % software without specific prior written permission.
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    % AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    % IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    % DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
    % FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    % DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    % SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    % CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    % OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    % OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    % 
    % key:      input secret key in char
    % message:  input message in char
    % method:   hash method, either:
    %           'SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if strcmp(method,'SHA-1') == 1
        Blocksize = 64;
    elseif strcmp(method,'SHA-256') == 1
        Blocksize = 64;
    elseif strcmp(method,'SHA-384') == 1
        Blocksize = 128;
    elseif strcmp(method,'SHA-512') == 1
        Blocksize = 128;
    else
        error('HMAC:Algorithm:Unavailable', ...
            'Algorithm `%s` not available.', method);
    end
    % if key length > Blocksize calculate Hash and format as binary
    if length(key) > Blocksize
        Opt.Method = method;
        Opt.Format = 'uint8';
        Opt.Input = 'bin';
        
        Hash_key = dj.lib.DataHash(uint8(key),Opt)
        
        for i = length(Hash_key):Blocksize
            Hash_key(1,i) = 0;
        end
        key_bin = uint82bin8(Hash_key);
    end
    % if key length < Blocksize right pad with zeros and format as binary
    if (length(key) > 0) && (length(key) < Blocksize)
        key_bin = str2bin8(key);
        L = length(key);
        for j = L+1:Blocksize
            key_bin{1,j} = [0 0 0 0 0 0 0 0];
        end
    end
    % if key length = 0 right pad with zeros and format as binary
    if length(key) ==0
        for j = 1:Blocksize
            key_bin{1,j} = [0 0 0 0 0 0 0 0];
        end
    end
    % if key length = Blocksize format key as binary numbers
    if length(key) == Blocksize
        key_bin = str2bin8(key);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % format inner and outer padding as binary cell arrays
    i_pad = [0 0 1 1 0 1 1 0];
    o_pad = [0 1 0 1 1 1 0 0];
    for i = 1:Blocksize
        i_pad_bin{1,i} = i_pad;
        o_pad_bin{1,i} = o_pad;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % calculate key xor ipad and key xor opad
    i_pad_key_bin = bit8xor(key_bin,i_pad_bin);
    o_pad_key_bin = bit8xor(key_bin,o_pad_bin);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Change format to uint8
    i_pad_key_hex = bin82hex(i_pad_key_bin);
    i_pad_key_uint8 = hex2uint8(i_pad_key_hex);
    o_pad_key_hex = bin82hex(o_pad_key_bin);
    o_pad_key_uint8 = hex2uint8(o_pad_key_hex);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % concatenate (i_pad_key || message)
    concat_i_pad = [i_pad_key_uint8,uint8(message)];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Calculate Hash of i_pad_key||message
    Opt.Method = method;
    Opt.Format = 'uint8';
    Opt.Input = 'bin';
    Hash_i_pad_uint8 = dj.lib.DataHash(concat_i_pad,Opt);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % concatenate (o_pad || Hash_i_pad)
    concat_o_pad = [o_pad_key_uint8,Hash_i_pad_uint8];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Calculate final Hash in HEX
    Opt.Method = method;
    Opt.Format = 'HEX';
    Opt.Input = 'bin';
    hash = dj.lib.DataHash(concat_o_pad,Opt);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % FORMAT HELP FUNCTIONS
    function bin = str2bin8(str)
    for i = 1:length(str)    
        temp = dec2bin(str2num(sprintf('%u',str(i))),8);
        for j = 1:8
            bin{1,i}(1,j) = str2num(temp(j));
        end
    end
    end
    function hex = bin82hex(bin)
    hex = cell(1,length(bin));
    for i = 1:length(bin)    
        string_bin = num2str(bin{1,i}(1,1)) ;
        for j = 2:8
            temp = num2str(bin{1,i}(1,j));
            string_bin = strcat(string_bin,temp);
        end
        hex{1,i} = dec2hex(bin2dec(string_bin));
    end
    end
    function v = bit8xor(a,b)
    if length(a) == length(b)
        for i = 1:length(a)
            v{1,i} = xor(a{1,i},b{1,i});
        end
    else
        ERROR = sprintf('%s','Input cells must be the same length')
    end
    end
    function out = hex2uint8(hex)
    for i = 1:length(hex)
        out(i) = hex2dec(hex{1,i});
    end
    out = uint8(out);
    end
    function bin = uint82bin8(in)
    bin = cell(1,length(in));
    for i = 1:length(in)
        temp = dec2bin(in(1,i),8);
        for j = 1:8
            bin{1,i}(1,j) = str2num(temp(j));
        end
    end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%