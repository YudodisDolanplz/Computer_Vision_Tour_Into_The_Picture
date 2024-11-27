function run_tour(app)
    
    % build rectangle out of top left and right botton point of rectangle
    rect = [app.P1(1), app.P1(2); ...
            app.P2(1), app.P2(2);
            app.P3(1), app.P3(2);
            app.P4(1), app.P4(2)];


    mask_fgobj(app);    % remove foreground objects and inpaint them
    
    [mesh, radiation] = calculate_mesh(rect, app.FP, size(app.img));

    surfaces = calculate_surfaces(rect, app.FP, mesh, radiation, app.masks, size(app.img), app.scaling_fact);

    textures = map_textures(uint8(app.imgd), app.img, app.masks, mesh, surfaces);  % imgd is the original image in double

    render(app.filename, mesh, surfaces, textures);
end