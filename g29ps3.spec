Usage Page (Desktop),               ; Generic desktop controls (01h)
Usage (Joystick),                   ; Joystick (04h, application collection)
Collection (Application),
    Usage (Hat Switch),             ; Hat switch (39h, dynamic value)
    Logical Minimum (0),
    Logical Maximum (7),
    Physical Minimum (0),
    Physical Maximum (315),
    Unit (Degrees),
    Report Size (4),
    Report Count (1),
    Input (Variable, Null State),
    Usage Page (Button),            ; Button (09h)
    Usage Minimum (01h),
    Usage Maximum (19h),
    Unit,
    Logical Maximum (1),
    Physical Maximum (1),
    Report Size (1),
    Report Count (25),
    Input (Variable),
    Report Size (1),
    Report Count (3),
    Input (Constant, Variable),
    Usage Page (Desktop),           ; Generic desktop controls (01h)
    Usage (X),                      ; X (30h, dynamic value)
    Logical Maximum (65535),
    Physical Maximum (65535),
    Report Size (16),
    Report Count (1),
    Input (Variable),
    Usage (Z),                      ; Z (32h, dynamic value)
    Usage (Rz),                     ; Rz (35h, dynamic value)
    Usage (Y),                      ; Y (31h, dynamic value)
    Logical Maximum (255),
    Physical Maximum (255),
    Report Size (8),
    Report Count (3),
    Input (Variable),
    Usage Page (FF00h),             ; FF00h, vendor-defined
    Usage (01h),
    Report Count (2),
    Input (Variable),
    Usage Page (FF00h),             ; FF00h, vendor-defined
    Usage (01h),
    Report Count (1),
    Input (Variable),
    Usage Page (FF00h),             ; FF00h, vendor-defined
    Usage (02h),
    Logical Maximum (255),
    Physical Maximum (255),
    Report Count (16),
    Report Size (8),
    Output (Variable),
End Collection
