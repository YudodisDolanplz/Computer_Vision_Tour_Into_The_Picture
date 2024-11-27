function controls(filename, X_min, X_max, Y_min, Y_max, Z_min, Z_max)
    % This code incorporates components from software copyrighted by
    % Joerg J. Buchholz (Hochschule Bremen, buchholz@hs-bremen.de)
    % under a BSD-style license (see license.txt for details).
    %
    % https://de.mathworks.com/matlabcentral/fileexchange/9340-doom-1-3
    %
    %      Changes:
    %       + Added collision
    %       + Added mouse wheel zoom
    %
    %      Controls:
    %       Mouse       : Look up, down, left, and right
    %       Mouse Wheel : Zoom
    %
    %       'w'     : Move forward
    %       's'     : Move backward
    %       'a'     : Move left
    %       'd'     : Move right
    %       'Space' : Fly up
    %       'c'     : Fly down
    %       'Shift' : Sprint
    %       'Esc'   : Close
    
    % FOV
    global FOV
    FOV = 75;

    % Collision
    margin = 0.05 * mean([abs(X_min - X_max), abs(Z_min - Z_max)]);
    X_min = X_min + margin;
    X_max = X_max - margin;
    Y_min = Y_min + margin;
    Z_min = Z_min + margin;
    Z_max = Z_max - margin;

    % Callbacks
    set(gcf, 'WindowButtonMotionFcn', @Mouse);
    set(gcf, 'WindowScrollWheelFcn', @MouseWheel);
    set(gcf, 'KeyPressFcn', @Key);

    % Set mouse pointer to crosshair
    iptPointerManager(gcf, 'enable');
    iptSetPointerBehavior(gcf, @(gcf, currentPoint) set(gcf, 'Pointer', 'crosshair'));

    % Minigame initialization
    minigame_starting = false;
    minigame_running = false;
    minigame_timer = timer('ExecutionMode', 'fixedRate', 'Period', 1);
    minigame_time = duration(0, 1, 0);

    ui_timer = 0;
    ui_score = 0;

    [coin_texture, ~, coin_texture_alpha] = imread('Functions/assets/coin.png');
    [coin_sound, coin_rate] = audioread('Functions/assets/sfx/coin.wav');
    coin_asset = 0;

    coin_X_pos = inf;
    coin_Y_pos = inf;
    coin_Z_pos = inf;

    [countdown_sound, countdown_rate] = audioread('Functions/assets/sfx/countdown.wav');
    [win_sound, win_rate] = audioread('Functions/assets/sfx/win.wav');
    [lose_sound, lose_rate] = audioread('Functions/assets/sfx/lose.wav');

    stats_file = 'stats.txt';
    stats_id = filename;

    if ~isfile(stats_file)
        fclose(fopen(stats_file, 'w'));
    end
    %%%%%%%%%%%%%%%%%%%%
   
    figure(gcf)
    figure_center;
    
    function [x_center, y_center] = figure_center
        % This function computes the center of the current figure
        % and positions the mouse cursor 
        % at the center of the current figure 
        
        % Joerg J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de, 2005
        
        % Get the position of the current figure
        figure_position = get(gcf, 'position');
        
        % Calculate the center coordinates of the current figure
        x_center = round(figure_position(1) + figure_position(3) / 2);
        y_center = round(figure_position(2) + figure_position(4) / 2);
        
        
        % Position the mouse cursor at the center of the current figure
        if ispc
            set(0, 'PointerLocation', [x_center, y_center]);
        else
            setmouse(x_center, y_center);
        end
    end
    
    function [dist, ch, ga, delta_axis, camera_position, camera_target] = polar_coordinates
        % This function computes the polar coordinates of the current view vector,
        % the plot box scaling vector, the current camera position, and the current camera target
        
        % Joerg J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de, 2005
        
        % Get the current camera position 
        camera_position = get(gca, 'CameraPosition');
        
        % Get the current camera target
        camera_target = get(gca, 'CameraTarget');
        
        % The camera view vector points from the camera position 
        % to the camera target
        camera_view = camera_target - camera_position;
        
        % Get the scaling (minimum and maximum values) of the current axis
        ax = axis;
        
        % Compute a scaling vector (maximum - minimum) for all three axes
        delta_axis = [ax(2) - ax(1), ax(4) - ax(3), ax(6) - ax(5)];
        
        % Normalize the camera view vector
        % i.e. transform the plot box into a unit cube.
        % This is necessary if the scalings of the single axes differ strongly.
        % Otherwise, the view rotation would be nonlinear
        % (with "faster" and "slower" areas of rotation)
        camera_view_normalized = camera_view ./ delta_axis;
        
        % Transform the camera view vector from cartesian to polar coordinates.
        % dist is the scalar distance between camera position and target
        % ch(i) is the azimuth angle in the earth-fixed (geodetical) x_g-y_g-plane
        % ga(mma) is the elevation angle about the view-fixed y_v-axis
        dist = norm(camera_view_normalized);
        ch = atan2(camera_view_normalized(2), camera_view_normalized(1));
        ga = -asin(camera_view_normalized(3) / dist);
    end
        
    function Mouse(~, ~)
        % This function is called whenever the mouse cursor has been moved 
        
        % Joerg J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de, 2005
        
        % Define the viewing angle increment (in radians per mouse resolution dot)
        angle_step = 0.0015;
        
        % Get the current position of the mouse cursor
        % with respect to the screen
        mouse_position = get(0, 'PointerLocation');
        
        % Get the center position of current figure
        % with respect to the screen
        [x_center, y_center] = figure_center;
        
        % Calculate the distances (in x and in y direction) 
        % the mouse has moved since the last call to this routine
        x_delta = mouse_position(1) - x_center;
        y_delta = mouse_position(2) - y_center;
        
        % Compute the polar coordinates of the current view vector,
        % the plot box scaling vector, the current camera position, and the current camera target
        [dist, ch, ga, delta_axis, camera_position, camera_target] = polar_coordinates;
        
        % Compute the new view angles depending on the distances
        % the mouse has moved since the last call to this routine.
        ch = ch - x_delta * angle_step;
        ga = ga - y_delta * angle_step;
        
        % The elevation angle gamma is defined between -pi/2 and +pi/2
        % and it must not be exactely +/- pi/2,
        % because MATLAB cannot render the scene 
        % if the camera UpVector is aligned with the view vector.
        % -> define a safety margin around +/- pi/2
        safety_margin = 0.001;
        
        % If the elevation angle exceeds the safety limit around pi/2
        if ga > pi/2 - safety_margin
        
            % set it back to the safety limit
            ga = pi/2 - safety_margin;
        
        % If the elevation angle exceeds the safety limit around -pi/2
        elseif ga < -pi/2 + safety_margin
        
            % set it back to the safety limit
            ga = -pi/2 + safety_margin;

        end
        
        % Transform the camera view vector from polar coordinates 
        % back to cartesian coordinates
        camera_view_normalized = [cos(ga) * cos(ch) cos(ga) * sin(ch) -sin(ga)] * dist;
        
        % Denormalize the camera view vector
        % i.e. transform the plot box from the intermediate unit cube 
        % back to the original cuboid.
        camera_view = camera_view_normalized .* delta_axis;
        
        % The camera target vector is the vector sum 
        % of the camera position vector and the camera view vector
        set(gca, 'CameraTarget', camera_position + camera_view);

        % drawnow cures freezing on some graphic cards
        drawnow
    end
    
    function MouseWheel(~, event)
        scroll_count = event.VerticalScrollCount;
        
        if scroll_count < 0
            FOV = max(FOV - 2, 10);
            camva(FOV);
        else
            FOV = min(FOV + 2, 100);
            camva(FOV);
        end
    end
    
    function Key(~, eventdata)
        % This function is called whenever a key has been pressed
        % It can easily be extended by appending a user-defined case block
        
        % Joerg J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de, 2005

        % Minigame routines
        if minigame_starting
            return;
        end

        if minigame_running
            minigame_udpate;
        end

        % Set the movement "distance" of a key pressed ('w', 'a', 's', 'd', ...)
        step_size = 0.0075;

        % Set the acceleration factor of a movement if the 'Shift' key is pressed
        % together with another key
        acceleration = 2;
        
        % Compute the polar coordinates of the current view vector,
        % the plot box scaling vector, the current camera position, and the current camera target
        [dist, ch, ga, delta_axis, camera_position, camera_target] = polar_coordinates;
        
        switch eventdata.Key
            case 's'
                % Compute the transformation of an x-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the first line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_x_normalized = [cos(ga) * cos(ch), cos(ga) * sin(ch), 0] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_x = delta_x_normalized .* delta_axis;

                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_x = delta_x * acceleration;
        
                end
        
                camera_position = camera_position - delta_x;

                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target - delta_x)

                end

            case 'w'
                % Compute the transformation of an x-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the first line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_x_normalized = [cos(ga) * cos(ch), cos(ga) * sin(ch), 0] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_x = delta_x_normalized .* delta_axis;

                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_x = delta_x * acceleration;
        
                end
        
                camera_position = camera_position + delta_x;

                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target + delta_x)

                end

            case 'a'
                % Compute the transformation of a y-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the second line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_y_normalized = [-sin(ch), cos(ch), 0] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_y = delta_y_normalized .* delta_axis;

                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_y = delta_y * acceleration;
        
                end

                camera_position = camera_position + delta_y;
                
                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target + delta_y)

                end

            case 'd'
                % Compute the transformation of a y-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the second line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_y_normalized = [-sin(ch), cos(ch), 0] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_y = delta_y_normalized .* delta_axis;

                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_y = delta_y * acceleration;
        
                end

                camera_position = camera_position - delta_y;
        
                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target - delta_y)

                end
            
            case 'c'
                % Compute the transformation of a z-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the third line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_z_normalized = [sin(ga) * cos(ch), sin(ga) * sin(ch), cos(ga)] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_z = delta_z_normalized .* delta_axis;

                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_z = delta_z * acceleration;
        
                end

                camera_position = camera_position - delta_z;
        
                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target - delta_z)

                end

            case 'space'
                % Compute the transformation of a z-step 
                % into the earth-fixed (geodetical) coordinate system.
                % The transformation vector is the third line 
                % of the transformation matrix M_k_g in
                % http://buchholz.hs-bremen.de/rtf/skript/skript10.pdf#Transformationsmatrizen
                delta_z_normalized = [sin(ga) * cos(ch), sin(ga) * sin(ch), cos(ga)] * step_size;
        
                % Denormalize the movement vector
                % i.e. transform the plot box from the intermediate unit cube 
                % back to the original cuboid.
                delta_z = delta_z_normalized .* delta_axis;
        
                if strcmp(eventdata.Modifier, 'shift')

                    % Make a bigger step
                    delta_z = delta_z * acceleration;
        
                end

                camera_position = camera_position + delta_z;
        
                if (camera_position(1) > X_min && camera_position(1) < X_max && ...
                    camera_position(2) > Y_min && camera_position(2) < inf && ...
                    camera_position(3) > Z_min && camera_position(3) < Z_max)

                    % Compute and set the new camera postion and camera target
                    set(gca, 'CameraPosition', camera_position)
                    set(gca, 'CameraTarget', camera_target + delta_z)

                end

            case 'm'
                if not(minigame_running)
                    minigame_start;
                end
            
            case 'escape'
                % Minigame cleanup
                stop(minigame_timer);
                delete(minigame_timer);

                close(gcf)

            % drawnow cures freezing on some graphic cards
            drawnow
        end
    end

    %%%%%%%%%%%%%%%%%%%%
    %  COIN MINIGAME!  %
    %%%%%%%%%%%%%%%%%%%%

    % Minigame functions
    function minigame_start
        minigame_starting = true;

        figure_position = get(gcf, 'Position');
        countdown_position = [round((figure_position(3) - 80) / 2) round(3 * figure_position(4) / 4)];

        % Countdown
        try
            sound(countdown_sound(:, 1), countdown_rate);
        catch
            ;
        end

        ui_countdown = uicontrol('Style', 'text', ...
                                 'Position', [countdown_position(1), countdown_position(2), 80, 60], ...
                                 'FontSize', 32, ...
                                 'FontWeight', 'bold', ...
                                 'String', '3', ...
                                 'BackgroundColor', [0.1, 0.1, 0.1], ...
                                 'ForegroundColor', [1, 1, 1], ...
                                 'HorizontalAlignment', 'center');

        pause(1)
        ui_countdown.String = '2';
        pause(1)
        ui_countdown.String = '1';
        pause(1)
        ui_countdown.String = 'Go!';
        pause(1)
        delete(ui_countdown)
    
        % Initialization
        initTimer(minigame_time);
        initScore;

        minigame_spawn;
        minigame_running = true;
        minigame_starting = false;
    end

    function minigame_udpate
        camera_position = get(gca, 'CameraPosition');
        if abs(camera_position(1) - coin_X_pos) <= 40 && ...
           abs(camera_position(2) - coin_Y_pos) <= 40 && ...
           abs(camera_position(3) - coin_Z_pos) <= 40
            delete(coin_asset)

            coin_X_pos = inf;
            coin_Y_pos = inf;
            coin_Z_pos = inf;

            updateScore;

            try
                sound(coin_sound, coin_rate, 8);
            catch
                ;
            end

            minigame_spawn;
        end
    end

    function minigame_finish
        delete(coin_asset)

        coin_X_pos = inf;
        coin_Y_pos = inf;
        coin_Z_pos = inf;

        writeHighscore;

        score_double = getScore;
        highscore_double = getHighscore;

        delete(ui_timer)
        delete(ui_score)

        figure_position = get(gcf, 'Position');
        figure_middle = [round((figure_position(3) - 300) / 2) round((figure_position(4) - 120) / 2)];

        ui_lastscore = uicontrol('Style', 'text', ...
                                 'Position', [figure_middle(1), figure_middle(2) + 60, 300, 60], ...
                                 'FontSize', 32, ...
                                 'FontWeight', 'bold', ...
                                 'String', ['Score: ' num2str(score_double)], ...
                                 'BackgroundColor', [0.1, 0.1, 0.1], ...
                                 'ForegroundColor', [1, 1, 1], ...
                                 'HorizontalAlignment', 'center');

        ui_highscore = uicontrol('Style', 'text', ...
                                 'Position', [figure_middle(1), figure_middle(2), 300, 60], ...
                                 'FontSize', 32, ...
                                 'FontWeight', 'bold', ...
                                 'String', ['Highscore: ' num2str(highscore_double)], ...
                                 'BackgroundColor', [0.1, 0.1, 0.1], ...
                                 'ForegroundColor', [0.8, 0.8, 0], ...
                                 'HorizontalAlignment', 'center');

        % Play final sound
        try
            if score_double >= highscore_double
                sound(win_sound(:, 1), win_rate);
                pause(length(win_sound) / win_rate);
            else
                sound(lose_sound(:, 1), lose_rate);
                pause(length(lose_sound) / lose_rate);
            end
        catch
            ;
        end

        delete(ui_lastscore)
        delete(ui_highscore)

        minigame_running = false;
    end

    function minigame_spawn
        coin_X_pos = -randi([round(X_max + margin), -round(X_min + margin)], 1);
        coin_Y_pos =  randi([round(Y_min + margin), round(Y_max - margin)], 1);
        coin_Z_pos =  randi([round(Z_min + margin), round(Z_max - margin)], 1);
    
        coin_X_data = [coin_X_pos + 20, coin_X_pos - 20; coin_X_pos + 20, coin_X_pos - 20];
        coin_Y_data = [coin_Y_pos, coin_Y_pos; coin_Y_pos, coin_Y_pos];
        coin_Z_data = [coin_Z_pos + 20, coin_Z_pos + 20; coin_Z_pos - 20, coin_Z_pos - 20];

        coin_asset = surface('XData', coin_X_data, 'YData', coin_Y_data, 'ZData', coin_Z_data, 'CData', coin_texture, ...
                             'FaceColor', 'texturemap', 'FaceAlpha', 'texturemap', 'AlphaData', coin_texture_alpha, ...
                             'EdgeColor', 'none', 'Clipping', 'off');
    end

    % Score functions
    function initScore
        figure_position = get(gcf, 'Position');

        ui_score = uicontrol('Style', 'text', ...
                             'Position', [figure_position(3) - 140, figure_position(4) - 40, 140, 40], ...
                             'FontSize', 20, ...
                             'FontWeight', 'bold', ...
                             'String', 'Score: 0', ...
                             'BackgroundColor', [0.1, 0.1, 0.1], ...
                             'ForegroundColor', [1, 1, 1], ...
                             'HorizontalAlignment', 'center');
    end

    function updateScore
        score_double = getScore;
        score_double = score_double + 1;

        ui_score.String =  ['Score: ' num2str(score_double)];
    end

    function score_double = getScore
        current_score = get(ui_score, 'String');

        score_int = regexp(current_score, '\d+', 'match');
        score_int = score_int{1};

        score_double = str2double(score_int);
    end

    function highscore_double = getHighscore
        fileID = fopen(stats_file, 'r');
        fileContent = textscan(fileID, '%s', 'Delimiter', '\n');
        fclose(fileID);

        content = fileContent{1};
        found = false;
        for i = 1:length(content)
            if contains(content{i}, stats_id)
                highscore_int = regexp(content{i}, '\d+', 'match');
                highscore_int = highscore_int{1};
                highscore_double = str2double(highscore_int);
                found = true;
                break;
            end
        end   

        if ~found
            highscore_double = 0;
        end
    end

    function writeHighscore
        fileID = fopen(stats_file, 'r');
        fileContent = textscan(fileID, '%s', 'Delimiter', '\n');
        fclose(fileID);

        score_double = getScore;
        highscore_double = getHighscore;

        if score_double > highscore_double
            content = fileContent{1};
            found = false;
            for i = 1:length(content)
                if contains(content{i}, stats_id)
                    % Update the line
                    content{i} = [sprintf('[%s]', stats_id), ' ', num2str(score_double)];
                    found = true;
                    break;
                end
            end   
    
            if ~found
                content{end+1} = [sprintf('[%s]', stats_id), ' ', num2str(score_double)];
            end
            
            % Write the updated content back to the file
            fileID = fopen(stats_file, 'w');
            for i = 1:length(content)
                fprintf(fileID, '%s\n', content{i});
            end
            fclose(fileID);
        end
    end

    % Timer functions
    function initTimer(duration)
        figure_position = get(gcf, 'Position');

        ui_timer = uicontrol('Style', 'text', ...
                             'Position', [0, figure_position(4) - 40, 80, 40], ...
                             'FontSize', 20, ...
                             'FontWeight', 'bold', ...
                             'String', formatTime(duration), ...
                             'BackgroundColor', [0.1, 0.1, 0.1], ...
                             'ForegroundColor', [1, 1, 1], ...
                             'HorizontalAlignment', 'center');
        ui_timer.UserData = duration;

        minigame_timer.TimerFcn = @(~,~) updateTimer(ui_timer);

        start(minigame_timer);
    end
    
    function updateTimer(timer)
        time = timer.UserData - seconds(1);
    
        if time <= seconds(0)
            timer.String = '00:00';
            stop(minigame_timer)
            minigame_finish;
        elseif time == seconds(10)
            timer.String = formatTime(time);
            timer.UserData = time;
            timer.ForegroundColor = [0.8, 0, 0];
        else
            timer.String = formatTime(time);
            timer.UserData = time;
        end
    end
    
    function time_formatted = formatTime(duration)
        time_seconds = seconds(duration);
        time_minutes = floor(mod(time_seconds, 3600) / 60);

        time_formatted = sprintf('%02d:%02d', time_minutes, mod(time_seconds, 60));
    end
end