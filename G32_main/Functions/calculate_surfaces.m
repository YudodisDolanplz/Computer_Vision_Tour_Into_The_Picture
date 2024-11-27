function surfaces = calculate_surfaces(rect, point, mesh, radiation, fgmasks, image_size, mem_threshold)

    % How to determine focal length?
    % Estimation through testing
    % Real model: sqrt(rect_size)
    % Box model: 3 * sqrt(rect_size)
    if strcmp(mesh.model, 'real')
        focal = sqrt((rect(2, 1) - rect(1, 1)) * (rect(4, 2) - rect(1, 2)));
    else
        focal = 3 * sqrt((rect(2, 1) - rect(1, 1)) * (rect(4, 2) - rect(1, 2)));
    end

    % Real model
    % Real depth calculation: https://github.com/yli262/tour-into-the-picture
    % Box model
    % Relative depth calculation: https://dl.acm.org/doi/abs/10.1145/1044588.1044594
    
    % Relative lengths calculation:
    depth = abs(rect(4, 2) - image_size(1)) * focal / (abs(point(2) - image_size(1)) - abs(rect(4, 2) - image_size(1)));
    width = (abs(rect(1, 1) - point(1)) + abs(rect(2, 1) - point(1))) * (focal + depth) / focal;
    height = abs(point(2) - image_size(1)) + abs(rect(1, 2) - point(2)) * (focal + depth) / focal;

    % Real model
    if strcmp(mesh.model, 'real')
        width = abs(rect(1, 1) - rect(2, 1));
        height = abs(rect(1, 2) - rect(4, 2));
    end

    % Memory fix
    % CHANGE QUALITY WITH THRESHOLD
    % mem_threshold = 7000;
    if max([depth, width, height]) > mem_threshold
        mem_scale = max([depth, width, height]) / mem_threshold;
    else
        mem_scale = 1;
    end

    focal = focal / mem_scale;

    depth = depth / mem_scale;
    width = width / mem_scale;
    height = height / mem_scale;

    % Rear wall
    P1 = [0, 0, 0];
    P2 = [width, 0, 0];
    P7 = [0, height, 0];
    P8 = [width, height, 0];

    surfaces.rearwall = struct('coords', [P7; P8; P2; P1], 'width', width, 'height', height);

    % Left wall
    if strcmp(mesh.model, 'real')
        depth = round((abs(point(1) - min(mesh.leftwall(1, 1), mesh.leftwall(4, 1))) * focal / abs(point(1) - rect(1, 1))) - focal);
    end

    leftwall_depth = depth;

    P5 = [0, 0, depth];
    P11 = [0, height, depth];

    surfaces.leftwall = struct('coords', [P11; P7; P1; P5], 'width', depth, 'height', height);

    % Right wall
    if strcmp(mesh.model, 'real')
        depth = round((abs(point(1) - max(mesh.rightwall(2, 1), mesh.rightwall(3, 1))) * focal / abs(point(1) - rect(2, 1))) - focal);
    end

    rightwall_depth = depth;

    P6 = [width, 0, depth];
    P12 = [width, height, depth];

    surfaces.rightwall = struct('coords', [P8; P12; P6; P2], 'width', depth, 'height', height);

    % Ceiling
    if strcmp(mesh.model, 'real')
        depth = round((abs(point(2) - min(mesh.ceiling(1, 2), mesh.ceiling(2, 2))) * focal / abs(point(2) - rect(1, 2))) - focal);
    end

    ceiling_depth = depth;

    P9 = [0, height, depth];
    P10 = [width, height, depth];

    surfaces.ceiling = struct('coords', [P9; P10; P8; P7], 'width', width, 'height', depth);

    % Floor
    if strcmp(mesh.model, 'real')
        depth = round((abs(point(2) - max(mesh.floor(3, 2), mesh.floor(4, 2))) * focal / abs(point(2) - rect(4, 2))) - focal);
    end

    floor_depth = depth;

    P3 = [0, 0, depth];
    P4 = [width, 0, depth];

    surfaces.floor = struct('coords', [P1; P2; P4; P3], 'width', width, 'height', depth);

    % Foreground objects
    %
    % Note: 
    % 2D image coordinates have their origin in the top-left corner
    % 3D world coordinates have their origin in the bottom-left corner

    for i = 1:length(fgmasks)
        % Find x- and y-min- and max-indices
        [y_idcs, x_idcs] = find(fgmasks{i} == 1);

        x_min = min(x_idcs);
        x_max = max(x_idcs);
        y_min = min(y_idcs);
        y_max = max(y_idcs);

        % Calculate texture size
        fgobj_texture_width = abs(x_min - x_max);
        fgobj_texture_height = abs(y_min - y_max);

        % Find texture point farthest away from vanishing point
        texture_point_1 = [x_min, y_min];
        texture_point_2 = [x_max, y_min];
        texture_point_3 = [x_max, y_max];
        texture_point_4 = [x_min, y_max];

        texture_points = [texture_point_1; texture_point_2; texture_point_3; texture_point_4];

        distances = sqrt(sum(bsxfun(@minus, texture_points, point) .^ 2, 2));
        [~, max_idx] = max(distances);

        % Use texture point farthest away from vanishing point as reference point
        reference_point = texture_points(max_idx, :);

        % Algorithm:
        % 1. Determine wall position of foreground object with radiation
        % 2. Determine x- and y-scales:
        %       - Calculate the distance between the wall radiation
        %       - Use this distance as the x- or y-scale (depending on which
        %         dimension the wall radiation bounds)
        %       - Calculate the distance between the projection of the
        %         reference point on the wall radiation and its reciprocal
        %         radiation
        %       - Use this distance as the remaining scale
        % 3. Scale texture sizes with scales
        %       3d_width = texture_width / scale_x * 2d_width
        %       3d_height = texture_height / scale_y * 2d_height
        % 4. Determine and scale x- and y-coordinates
        %       - Determine obvious x- or y- coordinate
        %       - Determine and scale second coordinate with radiation distance
        %       - Determine remaining coordinates with 3d_width and 3d_height
        % 5. Scale depth with radiation:
        %       fgobj_depth = wall_depth * scaling
        %       scaling = fgobj_radiation_length / wall_radiation_length


        % Radiation y-values with reference point
        r_topleft_y = radiation.topleft(1) * reference_point(1) + radiation.topleft(2);
        r_topright_y = radiation.topright(1) * reference_point(1) + radiation.topright(2);
        r_bottomright_y = radiation.bottomright(1) * reference_point(1) + radiation.bottomright(2);
        r_bottomleft_y = radiation.bottomleft(1) * reference_point(1) + radiation.bottomleft(2);
        % Radiation x-values with reference point
        r_topleft_x = (reference_point(2) - radiation.topleft(2)) / radiation.topleft(1);
        r_topright_x = (reference_point(2) - radiation.topright(2)) / radiation.topright(1);
        r_bottomleft_x = (reference_point(2) - radiation.bottomleft(2)) / radiation.bottomleft(1);
        r_bottomright_x = (reference_point(2) - radiation.bottomright(2)) / radiation.bottomright(1);


        % Rear wall
        if reference_point(1) > rect(1, 1) && reference_point(1) < rect(2, 1) && ...
           reference_point(2) > rect(1, 2) && reference_point(2) < rect(4, 2)

            scale_x = abs(rect(1, 1) - rect(2, 1));
            scale_y = abs(rect(1, 2) - rect(4, 2));

            fgobj_width = fgobj_texture_width / scale_x * width;
            fgobj_height = fgobj_texture_height / scale_y * height;

            fgobj_x_min = abs(x_min - rect(1, 1)) / scale_x * width;
            fgobj_x_max = fgobj_x_min + fgobj_width;
            fgobj_y_min = abs(rect(4, 2) - y_max) / scale_y * height;
            fgobj_y_max = fgobj_y_min + fgobj_height;

            % Use something larger than zero to prevent graphical glitches 
            fgobj_depth = 5;

        % Left wall
        elseif reference_point(1) > 0 && reference_point(1) < rect(1, 1) && ...
               reference_point(2) > r_topleft_y && reference_point(2) < r_bottomleft_y

            intersections = calculate_intersections(radiation.topleft(1), radiation.topleft(2), image_size);

            reciprocal_x = (r_topleft_y - radiation.topright(2)) / radiation.topright(1);

            scale_x = abs(reference_point(1) - reciprocal_x);
            scale_y = abs(r_topleft_y - r_bottomleft_y);
            scale_z = norm([reference_point(1) r_topleft_y] - rect(1, :)) / norm(intersections(1, :) - rect(1, :));

            fgobj_width = fgobj_texture_width / scale_x * width;
            fgobj_height = fgobj_texture_height / scale_y * height;

            fgobj_x_min = 0;
            fgobj_x_max = 0 + fgobj_width;
            fgobj_y_min = abs(r_bottomleft_y - y_max) / scale_y * width;
            fgobj_y_max = fgobj_y_min + fgobj_height;

            if strcmp(mesh.model, 'real')
                wall_depth = leftwall_depth;
            else
                wall_depth = depth;
            end

            fgobj_depth = min(wall_depth * scale_z, wall_depth);

        % Right wall
        elseif reference_point(1) > rect(2, 1) && reference_point(1) < image_size(2) && ...
               reference_point(2) > r_topright_y && reference_point(2) < r_bottomright_y

            intersections = calculate_intersections(radiation.topright(1), radiation.topright(2), image_size);

            reciprocal_x = (r_topright_y - radiation.topleft(2)) / radiation.topleft(1);

            scale_x = abs(reference_point(1) - reciprocal_x);
            scale_y = abs(r_topright_y - r_bottomright_y);
            scale_z = norm([reference_point(1) r_topright_y] - rect(2, :)) / norm(intersections(2, :) - rect(2, :));

            fgobj_width = fgobj_texture_width / scale_x * width;
            fgobj_height = fgobj_texture_height / scale_y * height;

            fgobj_x_min = width - fgobj_width;
            fgobj_x_max = width;
            fgobj_y_min = abs(r_bottomright_y - y_max) / scale_y * width;
            fgobj_y_max = fgobj_y_min + fgobj_height;

            if strcmp(mesh.model, 'real')
                wall_depth = rightwall_depth;
            else
                wall_depth = depth;
            end

            fgobj_depth = min(wall_depth * scale_z, wall_depth);

        % Ceiling
        elseif reference_point(1) > r_topleft_x && reference_point(2) < r_topright_x && ...
               reference_point(2) > 0 && reference_point(2) < rect(1, 2)

            intersections = calculate_intersections(radiation.topleft(1), radiation.topleft(2), image_size);

            reciprocal_y = radiation.bottomleft(1) * r_topleft_x + radiation.bottomleft(2);
            
            scale_x = abs(r_topleft_x - r_topright_x); 
            scale_y = abs(reference_point(2) - reciprocal_y);
            scale_z = norm([r_topleft_x reference_point(2)] - rect(1, :)) / norm(intersections(1, :) - rect(1, :));

            fgobj_width = fgobj_texture_width / scale_x * width;
            fgobj_height = fgobj_texture_height / scale_y * height;

            fgobj_x_min = abs(r_topleft_x - x_min)  / scale_x * width;
            fgobj_x_max = fgobj_x_min + fgobj_width;
            fgobj_y_min = height - fgobj_height;
            fgobj_y_max = height;

            if strcmp(mesh.model, 'real')
                wall_depth = ceiling_depth;
            else
                wall_depth = depth;
            end

            fgobj_depth = min(wall_depth * scale_z, wall_depth);

        % Floor
        elseif reference_point(1) > r_bottomleft_x && reference_point(1) < r_bottomright_x && ...
               reference_point(2) > rect(4, 2) && reference_point(2) < image_size(1)

            intersections = calculate_intersections(radiation.bottomleft(1), radiation.bottomleft(2), image_size);

            reciprocal_y = radiation.topleft(1) * r_bottomleft_x + radiation.topleft(2);

            scale_x = abs(r_bottomleft_x - r_bottomright_x);
            scale_y = abs(reference_point(2) - reciprocal_y);
            scale_z = norm([r_bottomleft_x reference_point(2)] - rect(4, :)) / norm(intersections(1, :) - rect(4, :));
            
            fgobj_width = fgobj_texture_width / scale_x * width;
            fgobj_height = fgobj_texture_height / scale_y * height;

            fgobj_x_min = abs(r_bottomleft_x - x_min) / scale_x * width;
            fgobj_x_max = fgobj_x_min + fgobj_width;
            fgobj_y_min = 0;
            fgobj_y_max = 0 + fgobj_height;

            if strcmp(mesh.model, 'real')
                wall_depth = floor_depth;
            else
                wall_depth = depth;
            end

            fgobj_depth = min(wall_depth * scale_z, wall_depth);
        end

        fgobj_coords1 = [fgobj_x_min, fgobj_y_max, fgobj_depth];
        fgobj_coords2 = [fgobj_x_max, fgobj_y_max, fgobj_depth];
        fgobj_coords3 = [fgobj_x_max, fgobj_y_min, fgobj_depth];
        fgobj_coords4 = [fgobj_x_min, fgobj_y_min, fgobj_depth];

        surfaces.(['fgobj' num2str(i)]) = struct('coords', [fgobj_coords1; fgobj_coords2; fgobj_coords3; fgobj_coords4], 'width', fgobj_texture_width, 'height', fgobj_texture_height);
    end
end

% Helper functions
function intersections = calculate_intersections(slope, intercept, image_size)
    % This function calculates the intersections of a line with the image borders
    % It returns the intersections sorted from left to right

    intersections = [];

    y_left = intercept;
    y_right = slope * image_size(2) + intercept;

    if slope ~= 0
        x_top = -intercept / slope;
        x_bottom = (image_size(1) - intercept) / slope;
    else
        x_top = NaN;
        x_bottom = NaN;
    end

    if y_left >= 0 && y_left <= image_size(1)
        intersections = [intersections; 0, y_left];
    end
    if y_right >= 0 && y_right <= image_size(1)
        intersections = [intersections; image_size(2), y_right];
    end
    if x_top >= 0 && x_top <= image_size(2)
        intersections = [intersections; x_top, 0];
    end
    if x_bottom >= 0 && x_bottom <= image_size(2)
        intersections = [intersections; x_bottom, image_size(1)];
    end

    if ~isempty(intersections)
        [~, sort_idx] = sort(intersections(:, 1));
        intersections = intersections(sort_idx, :);
    end
end