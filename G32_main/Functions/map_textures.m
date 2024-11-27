function textures = map_textures(image, image_inpaint, fgmasks, mesh, surfaces)
    hWaitbar = waitbar(0, 'Texturing...');

    fgmasks_idx = 1;
    surface_names = fieldnames(surfaces);
    for i = 1:numel(surface_names)
        id = surface_names{i};
        surface = surfaces.(id);
        surface_width = surface.width;
        surface_height = surface.height;

        if contains(id, 'fgobj')
            [texture, texture_alpha] = create_fgobj_texture(image, fgmasks{fgmasks_idx}, surface_width, surface_height);
            
            fgmasks_idx = fgmasks_idx + 1;
        else
            H = get_homography_matrix(mesh.(id), surface_width, surface_height);
    
            texture = warp_image(image_inpaint, H, surface_width, surface_height);
            texture_alpha = zeros(size(texture));
        end

        textures.(id) = struct('image', texture(:, :, 1:3), 'alpha', texture_alpha(:, :));

        waitbar(i/numel(surface_names), hWaitbar, 'Texturing...');
    end

    waitbar(1, hWaitbar, 'Your 3D Model will appear shortly. Please wait...');
    pause(2)
    close(hWaitbar);
end

% Helper functions
function H = get_homography_matrix(points, width, height)
    plain = [0, 0; width, 0; width, height; 0, height];
    H = fitgeotrans(points, plain, 'projective');
end

function texture = warp_image(image, H, width, height)
    ref2d = imref2d([round(height), round(width)]);
    texture = imwarp(image, H, 'OutputView', ref2d);
end

function [texture, texture_alpha] = create_fgobj_texture(image, mask, width, height)
    [y_idcs, x_idcs] = find(mask == 1);

    x_min = min(x_idcs);
    y_min = min(y_idcs);
  
    texture = zeros(height, width, 3, 'uint8');

    for y = 1:height
        for x = 1:width
            if mask(y_min + y - 1, x_min + x - 1)
                texture(y, x, 1:3) = image(y_min + y - 1, x_min + x - 1, 1:3);
            end
        end
    end

    texture_alpha = RGBA(texture);
    texture_alpha = texture_alpha(:, :, 4);
end

function texture_alpha = RGBA(image)
    [rows, cols, ~] = size(image);
    texture_alpha = zeros(rows, cols, 4, 'uint8');
    texture_alpha(:, :, 1:3) = image;
    for y = 1:rows
        for x = 1:cols
            if all(image(y, x, :) == 0)
                texture_alpha(y, x, 4) = 0;
            else
                texture_alpha(y, x, 4) = 255;
            end
        end
    end
end