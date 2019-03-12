Usage Page (Desktop),               ; Generic desktop controls (01h)
Usage (Joystick),                   ; Joystick (04h, application collection)
Collection (Application),
    Report ID (1),
    Usage (X),                      ; X (30h, dynamic value)
    Usage (Y),                      ; Y (31h, dynamic value)
    Usage (Z),                      ; Z (32h, dynamic value)
    Usage (Rz),                     ; Rz (35h, dynamic value)
    Logical Minimum (0),
    Logical Maximum (255),
    Report Size (8),
    Report Count (4),
    Input (Variable),
    Usage (Hat Switch),             ; Hat switch (39h, dynamic value)
    Logical Minimum (0),
    Logical Maximum (7),
    Physical Minimum (0),
    Physical Maximum (315),
    Unit (Degrees),
    Report Size (4),
    Report Count (1),
    Input (Variable, Null State),
    Unit,
    Usage Page (Button),            ; Button (09h)
    Usage Minimum (01h),
    Usage Maximum (0Eh),
    Logical Minimum (0),
    Logical Maximum (1),
    Report Size (1),
    Report Count (14),
    Input (Variable),
    Usage Page (FF00h),             ; FF00h, vendor-defined
    Usage (20h),
    Report Size (6),
    Report Count (1),
    Input (Variable),
    Usage Page (Desktop),           ; Generic desktop controls (01h)
    Usage (Rx),                     ; Rx (33h, dynamic value)
    Usage (Ry),                     ; Ry (34h, dynamic value)
    Logical Minimum (0),
    Logical Maximum (255),
    Report Size (8),
    Report Count (2),
    Input (Variable),
    Usage Page (FF00h),             ; FF00h, vendor-defined
    Usage (21h),
    Report Count (54),
    Input (Variable),
    Report ID (5),
    Usage (22h),
    Report Count (31),
    Output (Variable),
    Report ID (3),
    Usage (2721h),
    Report Count (47),
    Feature (Variable),
End Collection,
Usage Page (FFF0h),                 ; FFF0h, vendor-defined
Usage (40h),
Collection (Application),
    Report ID (240),
    Usage (47h),
    Report Count (63),
    Feature (Variable),
    Report ID (241),
    Usage (48h),
    Report Count (63),
    Feature (Variable),
    Report ID (242),
    Usage (49h),
    Report Count (15),
    Feature (Variable),
    Report ID (243),
    Usage (4701h),
    Report Count (7),
    Feature (Variable),
End Collection
