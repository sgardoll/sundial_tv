# main.py - Sundial Clock for Pimoroni Presto
# Requires Pimoroni MicroPython firmware

import utime as time
import machine
import math
from picographics import PicoGraphics, DISPLAY_PRESTO, PEN_RGB565

# Initialize display
display = PicoGraphics(display=DISPLAY_PRESTO, pen_type=PEN_RGB565)
WIDTH, HEIGHT = display.get_bounds()

# Initialize RTC
rtc = machine.RTC()

# Use a built-in vector font
display.set_font("sans")

def create_pen(r, g, b):
    return display.create_pen(int(r), int(g), int(b))

# Color Palette
BG_DAY = (224, 229, 236)
BG_NIGHT = (26, 37, 47)
BG_SUNRISE = (220, 180, 148)
BG_SUNSET = (201, 150, 125)

TEXT_DAY = (232, 236, 239)
TEXT_NIGHT = (44, 62, 80)
TEXT_SUNRISE = (240, 230, 216)
TEXT_SUNSET = (235, 220, 211)

SHADOW_DAY = (100, 110, 130)
SHADOW_NIGHT = (100, 130, 160)

def blend(c1, c2, factor):
    return (
        int(c1[0] + (c2[0] - c1[0]) * factor),
        int(c1[1] + (c2[1] - c1[1]) * factor),
        int(c1[2] + (c2[2] - c1[2]) * factor)
    )

def interpolate_color(c1, c2, factor):
    return create_pen(*blend(c1, c2, factor))

while True:
    # Get local time using machine.RTC()
    # datetime() returns: (year, month, day, weekday, hours, minutes, seconds, subseconds)
    t = rtc.datetime()
    hours = t[4]
    minutes = t[5]
    seconds = t[6]
    
    # Continuous time for smooth shadow angles
    time_val = hours + minutes / 60.0 + seconds / 3600.0
    
    display_hour = hours % 12
    if display_hour == 0:
        display_hour = 12
        
    text = str(display_hour)
    is_daytime = 6 <= time_val < 18
    
    # Smooth background and text color transitions
    if 3 <= time_val < 6:
        factor = (time_val - 3) / 3.0
        bg_color = blend(BG_NIGHT, BG_SUNRISE, factor)
        text_color_rgb = blend(TEXT_NIGHT, TEXT_SUNRISE, factor)
    elif 6 <= time_val < 9:
        factor = (time_val - 6) / 3.0
        bg_color = blend(BG_SUNRISE, BG_DAY, factor)
        text_color_rgb = blend(TEXT_SUNRISE, TEXT_DAY, factor)
    elif 9 <= time_val < 15:
        bg_color = BG_DAY
        text_color_rgb = TEXT_DAY
    elif 15 <= time_val < 18:
        factor = (time_val - 15) / 3.0
        bg_color = blend(BG_DAY, BG_SUNSET, factor)
        text_color_rgb = blend(TEXT_DAY, TEXT_SUNSET, factor)
    elif 18 <= time_val < 21:
        factor = (time_val - 18) / 3.0
        bg_color = blend(BG_SUNSET, BG_NIGHT, factor)
        text_color_rgb = blend(TEXT_SUNSET, TEXT_NIGHT, factor)
    else:
        bg_color = BG_NIGHT
        text_color_rgb = TEXT_NIGHT

    display.set_pen(create_pen(*bg_color))
    display.clear()
    text_color = create_pen(*text_color_rgb)
    
    if is_daytime:
        celestial_angle = ((time_val - 6) / 12.0) * math.pi
        shadow_color = SHADOW_DAY
    else:
        night_time = time_val + 24 if time_val < 6 else time_val
        celestial_angle = ((night_time - 18) / 12.0) * math.pi
        shadow_color = SHADOW_NIGHT
        
    # Calculate shadow direction
    shadow_angle = celestial_angle + math.pi
    dx = math.cos(shadow_angle)
    dy = math.sin(shadow_angle)
    
    # Calculate shadow length based on elevation
    elevation = max(0, math.sin(celestial_angle))
    shadow_length = 10 + (1.0 - elevation) * 80 # Amped up shadow length
    
    steps = 20 # More steps for smoother, longer shadow
    text_scale = 8
    
    # Center text
    text_width = display.measure_text(text, text_scale)
    text_height = text_scale * 8 # Approximate height
    center_x = (WIDTH - text_width) // 2
    center_y = (HEIGHT - text_height) // 2
    
    # Draw shadow (multiple offset layers)
    for i in range(steps, 0, -1):
        progress = i / steps
        offset_x = int(dx * shadow_length * progress)
        offset_y = int(dy * shadow_length * progress)
        
        # Fade shadow into background
        pen = interpolate_color(bg_color, shadow_color, 1.0 - progress)
        display.set_pen(pen)
        display.text(text, center_x + offset_x, center_y + offset_y, -1, text_scale)
        
    # Draw main text
    display.set_pen(text_color)
    display.text(text, center_x, center_y, -1, text_scale)
    
    display.update()
    
    # Update every second
    time.sleep(1)
