function love.conf(t)
    t.window = false
    t.identity = "mari0_2"
    t.version = "11.3"
    t.modules.touch = true

    -- Android: store save data on external storage
    -- (/sdcard/Android/data/<package>/files), so it can be reached with
    -- Shizuku + ZArchiver or a USB cable without root.
    t.externalstorage = true
end
