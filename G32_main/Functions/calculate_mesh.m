function [mesh, radiation] = calculate_mesh(rect, point, image_size)
    P7 = rect(1,:);
    P8 = rect(2,:);
    P2 = rect(3,:);
    P1 = rect(4,:);

    % Top-left line
    slope = (point(2) - rect(1,2)) / (point(1) - rect(1,1));
    intercept = rect(1,2) - slope * rect(1,1);
    P9 = [-intercept / slope, 0];
    P11 = [0, intercept];

    radiation.topleft = [slope, intercept];

    % Top-right line
    slope = (point(2) - rect(2,2)) / (point(1) - rect(2,1));
    intercept = rect(2,2) - slope * rect(2,1);
    P10 = [-intercept / slope, 0];
    P12 = [image_size(2), slope * image_size(2) + intercept];

    radiation.topright = [slope, intercept];

    % Bottom-right line
    slope = (point(2) - rect(3,2)) / (point(1) - rect(3,1));
    intercept = rect(3,2) - slope * rect(3,1);
    P4 = [(image_size(1) - intercept) / slope, image_size(1)];
    P6 = [image_size(2), slope * image_size(2) + intercept];

    radiation.bottomright = [slope, intercept];

    % Bottom-left line
    slope = (point(2) - rect(4,2)) / (point(1) - rect(4,1));
    intercept = rect(4,2) - slope * rect(4,1);
    P3 = [(image_size(1) - intercept) / slope, image_size(1)];
    P5 = [0, slope * 0 + intercept];

    radiation.bottomleft = [slope, intercept];

    % Construct mesh
    middle_axis = floor(image_size(2) / 2);
    tolerance = floor(1/24 * image_size(2));

    % Use box model for objects with vanishing point close to rectangle
    if abs(point(1) - rect(1, 1)) < tolerance || ...
       abs(point(1) - rect(2, 1)) < tolerance || ...
       abs(point(2) - rect(1, 2)) < tolerance || ...
       abs(point(2) - rect(4, 2)) < tolerance
        mesh.model = 'box';
        mesh.rearwall = [P7; P8; P2; P1];
        mesh.leftwall = [P9; P7; P1; P3];
        mesh.rightwall = [P8; P10; P4; P2];
        mesh.ceiling = [P9; P10; P8; P7];
        mesh.floor = [P1; P2; P4; P3];
    else
        mesh.model = 'real';
        mesh.rearwall = [P7; P8; P2; P1];
        mesh.leftwall = [P11; P7; P1; P5];
        mesh.rightwall = [P8; P12; P6; P2];
        mesh.ceiling = [P9; P10; P8; P7];
        mesh.floor = [P1; P2; P4; P3];
    end
end