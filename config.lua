MBT = MBT or {}

-------------------------------------------------------------------------------
-- [ SECTION 1: GLOBAL SETTINGS ] --
-------------------------------------------------------------------------------

MBT.Language = 'en' -- Options: 'en', 'it', 'es' (loads from locales/*.lua — add your own there)
MBT.Debug    = false -- Enable Utils.MbtDebugger logs

MBT.General = {
    InteractKey = 'E', -- Key used to pass through Enter/Exit points
}

-------------------------------------------------------------------------------
-- [ SECTION 2: GAMEPLAY ] --
-------------------------------------------------------------------------------

-- Players that clip BELOW this Z while falling are pulled into the backrooms.
-- Kept at 0.0 so it only triggers when you glitch under the map, NOT when you
-- fall from buildings / great heights.
MBT.FallingPoint = 0.0

-- Chance (%) that an Exit point teleports you into ANOTHER backroom instead of
-- back to the surface. Faithful to the lore: getting out is not guaranteed.
MBT.ExitToBackroomChance = 70

-- Interior spawn coords, one entry per backroom level.
MBT.Coords = {
    vector3(1026.88, 801.66, 25.88),   -- lvl_01 Iakko
    vector3(1780.18, -274.04, 20.66),  -- lvl_02 Iakko
    vector3(356.42, 5530.52, 14.37),   -- lvl_03 Iakko
    vector3(-2284.94, 1432.59, 81.70)  -- lvl_04 Iakko
}

-- Surface points a player can be spit back out to when they manage to exit.
MBT.RandomExitPoint = {
    vector3(-3090.44, 3322.13, 11.41),
    vector3(1163.97, 5964.91, 407.65),
    vector3(-557.24, 1890.37, 123.75),
    vector3(-54.04, 33.76, 1924.76),
    vector3(-159.57, -975.7, 115.28),
    vector3(1753.06, 4228.73, -5.85)
}

-- Interaction points placed around the map.
--   Type = "Enter" -> always teleports into a random backroom.
--   Type = "Exit"  -> MBT.ExitToBackroomChance% to land in another backroom,
--                     otherwise teleports to a random surface exit point.
MBT.BackRooms = {
    { Type = "Exit",  Coords = vector3(310.52, 5522.78, 14.51),   Range = 1.5 },
    { Type = "Exit",  Coords = vector3(1779.16, -260.81, 20.86),  Range = 1.5 },
    { Type = "Exit",  Coords = vector3(-2301.72, 1416.78, 81.92), Range = 1.5 },
    { Type = "Exit",  Coords = vector3(1017.94, 800.23, 25.92),   Range = 1.5 },
    { Type = "Enter", Coords = vector3(1112.08, 2188.65, 46.39),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-220.38, 3649.13, 51.75),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-440.85, 1598.89, 358.47), Range = 2.0 },
    { Type = "Enter", Coords = vector3(1665.08, -28.03, 196.94),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(3426.76, 5174.49, 7.41),   Range = 2.0 }
}
