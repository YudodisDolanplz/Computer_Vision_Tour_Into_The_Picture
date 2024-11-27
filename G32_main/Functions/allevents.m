function allevents(src,evt,app)
% handles all events from ROI objects, e.g. when moving

    evname = evt.EventName;
    switch(evname)
        case{'MovingROI'}
            % update coords of vertices and vanishing point
            if class(src) == "images.roi.Rectangle"
                app.P1 = [evt.Source.Position(1), evt.Source.Position(2)];
                app.P2 = [evt.Source.Position(1)+evt.Source.Position(3), evt.Source.Position(2)];
                app.P3 = [evt.Source.Position(1)+evt.Source.Position(3), evt.Source.Position(2)+evt.Source.Position(4)];
                app.P4 = [evt.Source.Position(1), evt.Source.Position(2)+evt.Source.Position(4)];
            elseif class(src) == "images.roi.Polygon"
                app.P1 = evt.Source.Position(1,:);
                app.P2 = evt.Source.Position(2,:);
                app.P3 = evt.Source.Position(3,:);
                app.P4 = evt.Source.Position(4,:);
            elseif class(src) == "images.roi.Point" 
                app.FP = evt.Source.Position;
            end
            
            draw_lines(app);    % plot the lines into the image
            
        case{'ROIMoved'}
            % used when only update something when it finished moving
    end
end
