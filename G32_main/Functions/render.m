function render(filename, mesh, surfaces, textures)
    % Disable due to bugs under Linux X11
    %hWaitbar = waitbar(0, 'Rendering 3D Model...');

    screensize = get(0, 'screensize');
    screenwidth = screensize(3);
    screenheight = screensize(4);

    width = 1000;
    height = 800;
    posX = (screenwidth - width) / 2;
    posY = (screenheight - height) / 2;

    figure('Name', '3D Model', 'NumberTitle', 'off', ...
           'MenuBar', 'none', 'ToolBar', 'none', ...
           'Position', [posX, posY, width, height], ...
           'Color', [0, 0, 0]);

    % Controls info
    uicontrol('Style', 'text', ...
              'Position', [0, 0, 635, 20], ...
              'FontSize', 10, ...
              'String', '[W|A|S|D] Move, [Shift] Sprint, [Mouse] Look, [Mouse Wheel] Zoom, [Space|C] Fly, [M] Surprise, [Esc] Exit', ...
              'BackgroundColor', [0.1, 0.1, 0.1], ...
              'ForegroundColor', [1, 1, 1]);

    XYZ = [];

    transformed_surfaces = transform_coords(surfaces);

    surface_names = fieldnames(surfaces);
    for i = 1:numel(surface_names)
        id = surface_names{i};
        coords = transformed_surfaces.(id);
        image = textures.(id).image;
        alpha = textures.(id).alpha;
        
        X = [coords(1, 1), coords(2, 1); coords(4, 1), coords(3, 1)];
        Y = [coords(1, 2), coords(2, 2); coords(4, 2), coords(3, 2)];
        Z = [coords(1, 3), coords(2, 3); coords(4, 3), coords(3, 3)];

        XYZ = vertcat(XYZ, coords);
        
        surface('XData', X, 'YData', Y, 'ZData', Z, 'CData', image, ...
                'FaceColor', 'texturemap', 'FaceAlpha', 'texturemap', 'AlphaData', alpha, ...
                'EdgeColor', 'none', 'Clipping', 'off');

        %waitbar(i/numel(surface_names), hWaitbar, 'Rendering 3D Model...');
    end

    % Render image frame only for box model
    if strcmp(mesh.model, 'box')
        [frame, ~, frame_alpha] = imread('Functions/assets/frame.png');
    
        X_frame = [max(XYZ(:, 1)), min(XYZ(:, 1)); max(XYZ(:, 1)), min(XYZ(:, 1))];
        Y_frame = [max(XYZ(:, 2)), max(XYZ(:, 2)); max(XYZ(:, 2)), max(XYZ(:, 2))];
        Z_frame = [max(XYZ(:, 3)), max(XYZ(:, 3)); min(XYZ(:, 3)), min(XYZ(:, 3))];
    
        surface('XData', X_frame, 'YData', Y_frame, 'ZData', Z_frame, 'CData', frame, ...
                'FaceColor', 'texturemap', 'FaceAlpha', 'texturemap', 'AlphaData', frame_alpha, ...
                'EdgeColor', 'none', 'Clipping', 'off');
    end
 
    axis vis3d;
    axis equal;
    axis off;
    grid off;

    set(gcf, 'Renderer', 'opengl');

    controls(filename, ...
             min(XYZ(:, 1)), max(XYZ(:, 1)), ...
             min(XYZ(:, 2)), max(XYZ(:, 2)), ...
             min(XYZ(:, 3)), max(XYZ(:, 3)))

    % Initial camera parameters
    center = mean(XYZ);
    
    campos([center(1), max(XYZ(:, 2)) + center(2), center(3)]);
    camtarget([center(1), 0, center(3)]);
    camproj('perspective');
    camva(75);

    %waitbar(1, hWaitbar, 'Rendering 3D Model...');
    %close(hWaitbar);
end

% Helper functions
function transformed = transform_coords(surfaces)
    surface_names = fieldnames(surfaces);
    for i = 1:numel(surface_names)
        id = surface_names{i};
        coords = surfaces.(id).coords;

        % Mirror x-axis
        coords(:, 1) = -coords(:, 1);
        % Swap y- and z-axis
        coords(:, [2, 3]) = coords(:, [3, 2]);

        transformed.(id) = coords;
    end
end