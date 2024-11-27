function draw_lines(app)
% draw lines in image that go through FP and IR edges. Deletes previous line plots

if ~isempty(app.FP) && ~isempty(app.P1)
    if ~isempty(app.lineplot), delete(app.lineplot); end    % delete previous line
    hold(app.UIAxes, 'on' )
    
    % compute coords of intersection with image borders
    % linex = [app.P1(1), 0; ...
    %          app.P2(1), size(app.imgd,2);
    %          app.P3(1), size(app.imgd,2);
    %          app.P4(1), 0];
    % liney = [app.P1(2), app.FP(2) - (app.FP(2) - app.P1(2)) / (app.FP(1) - app.P1(1))*app.FP(1); ...
    %          app.P2(2), app.FP(2) - (app.FP(2) - app.P2(2)) / (app.FP(1) - app.P2(1))*(app.FP(1)-size(app.imgd,2));
    %          app.P3(2), app.FP(2) - (app.FP(2) - app.P3(2)) / (app.FP(1) - app.P3(1))*(app.FP(1)-size(app.imgd,2));
    %          app.P4(2), app.FP(2) - (app.FP(2) - app.P4(2)) / (app.FP(1) - app.P4(1))*app.FP(1)];

    linex = zeros(4,2);
    linex(:,1) = [app.P1(1); app.P2(1); app.P3(1); app.P4(1)];
    liney = zeros(4,2);
    liney(:,1) = [app.P1(2); app.P2(2); app.P3(2); app.P4(2)];

    % consider cases where FP outside of rectangle
    if app.P1(1) > app.FP(1)    % outside
        linex(1,2) = size(app.imgd,2); 
        liney(1,2) = (app.FP(2) - (app.FP(2) - app.P1(2)) / (app.FP(1) - app.P1(1))*(app.FP(1)-size(app.imgd,2)));
    else    % inside
        linex(1,2) = 0;
        liney(1,2) = app.FP(2) - (app.FP(2) - app.P1(2)) / (app.FP(1) - app.P1(1))*app.FP(1);
    end
    if app.P2(1) < app.FP(1)
        linex(2,2) = 0;
        liney(2,2) = app.FP(2) - (app.FP(2) - app.P2(2)) / (app.FP(1) - app.P2(1))*app.FP(1);
    else
        linex(2,2) = size(app.imgd,2);
        liney(2,2) = app.FP(2) - (app.FP(2) - app.P2(2)) / (app.FP(1) - app.P2(1))*(app.FP(1)-size(app.imgd,2));
    end
    if app.P3(1) < app.FP(1)
        linex(3,2) = 0;
        liney(3,2) = app.FP(2) - (app.FP(2) - app.P3(2)) / (app.FP(1) - app.P3(1))*app.FP(1);
    else
        linex(3,2) = size(app.imgd,2);
        liney(3,2) = app.FP(2) - (app.FP(2) - app.P3(2)) / (app.FP(1) - app.P3(1))*(app.FP(1)-size(app.imgd,2));
    end
    if app.P4(1) > app.FP(1)
        linex(4,2) = size(app.imgd,2);
        liney(4,2) = app.FP(2) - (app.FP(2) - app.P4(2)) / (app.FP(1) - app.P4(1))*(app.FP(1)-size(app.imgd,2));
    else
        linex(4,2) = 0;
        liney(4,2) = app.FP(2) - (app.FP(2) - app.P4(2)) / (app.FP(1) - app.P4(1))*app.FP(1);
    end

    % plot lines
    app.lineplot = plot(app.UIAxes, linex', liney', 'Color', 'g', 'LineWidth', 1); %'Color', [0, 0.4470, 0.7410]);

    hold(app.UIAxes, 'off' )
    app.UIAxes.Children = app.UIAxes.Children([5:end-1, 1:4, end]);     % change hierarchy so that lines don't block rect edges

end

end
