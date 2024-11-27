function setmouse(x,y)
    import java.awt.Robot;

    screensize = get(0, 'screensize');
    y = screensize(4) - y;

    mouse = Robot;
    mouse.mouseMove(x - 1, y);
end