function use32BitDims(flag)
    % SAVEGLOBAL()
    %   Description:
    %     Sets the environment variable flag for reading 32-bit data
    %   Examples:
    %     dj.config.use32BitDims(true)
    if flag
        dj.internal.Settings.use32BitDims(true);
    else
        dj.internal.Settings.use32BitDims(false);
    end
end 