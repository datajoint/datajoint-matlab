function out = restore()
    % RESTORE()
    %   Description:
    %     Restores the configuration to initial default.
    %   Examples:
    %     dj.config.restore
    out = dj.internal.Settings.restore();
end