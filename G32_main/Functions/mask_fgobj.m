
function mask_fgobj(app)
% inpaint the polygon areas

if isempty(app.fgobj)
    app.img = uint8(app.imgd);  % reset polygons if no fgobjects
    app.masks = {};
    return;
end


hWaitbar = waitbar(0, 'Processing Foreground Objects...');

app.masks = cellfun(@createMask, app.fgobj, 'UniformOutput', false);    % create mask for fg objects
img_temp = app.imgd;    % imgd will stay unaltered, only apply inpaint to img, so that we still have the original image

% do it in for loop for every polygon
N = numel(app.masks);
for i = 1:length(app.masks)
    % if area of polygon is too large, choose the faster inpaint function
    polygonarea = polyarea(app.fgobj{i}.Position(:,1), app.fgobj{i}.Position(:,2));
    % tic
    if polygonarea < app.maxfgarea      % use most costly inpaint for small fgobjects
        img_temp = inpaintExemplar(img_temp,app.masks{i}, 'PatchSize', [9 9]);
    elseif polygonarea < 40*app.maxfgarea    % use faster inpaint for large fgobjects
        img_temp = inpaintCoherent(img_temp,app.masks{i}, 'SmoothingFactor', 0.8, 'Radius', 10);
    else    % for really large fgobjects, just delete them from the picture
        img_temp = img_temp .* ~app.masks{i};
    end
    % toc
    waitbar(i/N, hWaitbar, 'Processing Foreground Objects...'); 
end

app.img = uint8(img_temp);
close(hWaitbar);

end
