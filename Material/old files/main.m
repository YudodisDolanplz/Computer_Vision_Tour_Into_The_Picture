function main
    addpath('include');

    screensize = get(0,'screensize');
    screenwidth = screensize(3);
    screenheight = screensize(4);

    width = 800;
    height = 600;
    posX = (screenwidth - width) / 2;
    posY = (screenheight - height) / 2;

    hFigure = figure('Name', 'Tour into the Picture', 'NumberTitle', 'off', ...
                     'MenuBar', 'none', 'ToolBar', 'none', ...
                     'Position', [posX, posY, width, height], ...
                     'Color', [0.1, 0.1, 0.1]);

    hAxes = axes('Parent', hFigure, ...
                 'Position', [0, 0.15, 1, 0.8], ...
                 'Color', [0.1, 0.1, 0.1]);

    image = [];

    hRect = [];
    hPoint = [];
    hMesh = [];
    
    axis off;

    uicontrol('Style', 'pushbutton', 'String', 'Load Image', ...
              'Position', [60, 30, 310, 30], ...
              'Callback', @load, ...
              'BackgroundColor', [0.2, 0.2, 0.2], 'ForegroundColor', 'w');

    uicontrol('Style', 'pushbutton', 'String', 'Start your Tour into the Picture', ...
              'Position', [430, 30, 310, 30], ...
              'Callback', @process, ...
              'BackgroundColor', [0.2, 0.2, 0.2], 'ForegroundColor', 'w');

    function draw(~)
        [imHeight, imWidth, ~] = size(image);

        if isempty(hRect)
            rect_width = imWidth / 2;
            rect_height = imHeight / 2;
            rect_position = [(imWidth - rect_width) / 2, (imHeight - rect_height) / 2, rect_width, rect_height];
            hRect = imrect(hAxes, rect_position);
            addNewPositionCallback(hRect, @(pos) draw(pos));
        else
            rect_position = getPosition(hRect);
            setPosition(hRect, rect_position);
        end

        if isempty(hPoint)
            point_position = [imWidth / 2, imHeight / 2];
            hPoint = impoint(hAxes, point_position);
            addNewPositionCallback(hPoint, @(pos) draw(pos));
        else
            point_position = getPosition(hPoint);
            setPosition(hPoint, point_position);
        end

        rect = [rect_position(1), rect_position(2); ...
                rect_position(1) + rect_position(3), rect_position(2); ...
                rect_position(1) + rect_position(3), rect_position(2) + rect_position(4); ...
                rect_position(1), rect_position(2) + rect_position(4)];

        point = point_position;

        mesh = calculate_mesh(rect, point, size(image));

        P4 = mesh.floor(3, :); 
        P5 = mesh.leftwall(4, :);
        P10 = mesh.ceiling(2, :);
        P11 = mesh.leftwall(1, :);

        if ~isempty(hMesh)
            delete(hMesh);
        end

        hold on;
        % These offsets are a very dirty way to fix the issue of the lines
        % disturbing the user input. Please fix!
        x_offset = imWidth * 0.005;
        y_offset = imHeight * 0.005;
        hMesh(1) = line([P11(1) rect(1, 1) - x_offset], [P11(2) rect(1, 2) - y_offset], ...
                   'Color', 'b', 'LineWidth', 2);
        hMesh(2) = line([P10(1) rect(2, 1) + x_offset], [P10(2) rect(2, 2) - y_offset], ...
                   'Color', 'b', 'LineWidth', 2);
        hMesh(3) = line([P4(1) rect(3, 1) + x_offset], [P4(2) rect(3, 2) + y_offset], ...
                   'Color', 'b', 'LineWidth', 2);
        hMesh(4) = line([P5(1) rect(4, 1) - x_offset], [P5(2) rect(4, 2) + y_offset], ...
                   'Color', 'b', 'LineWidth', 2);
        hold off;
    end

    function load(~, ~)
        [filename, pathname] = uigetfile('*.jpg;*.png;*.bmp', 'Select an image', 'images');

        if isequal(filename, 0)
            return;
        end

        clearvars image hRect hPoint hMesh;

        hRect = [];
        hPoint = [];
        hMesh = [];
        
        image = imread(fullfile(pathname, filename));
        imshow(image, 'Parent', hAxes);

        draw()
    end

    function process(~, ~)
        if isempty(image)
            errordlg('Please load an image first.', 'Error');
            return;
        end

        rect_position = getPosition(hRect);
        rect = [rect_position(1), rect_position(2); ...
                rect_position(1) + rect_position(3), rect_position(2); ...
                rect_position(1) + rect_position(3), rect_position(2) + rect_position(4); ...
                rect_position(1), rect_position(2) + rect_position(4)];

        point = getPosition(hPoint);

        
        mesh = calculate_mesh(rect, point, size(image));
        surfaces = calculate_surfaces(rect, point, mesh, size(image));

        textures = map_textures(image, mesh, surfaces);

        
        render(surfaces, textures);
    end
end