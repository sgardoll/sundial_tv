'use client';

import { useEffect, useState, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Cast } from 'lucide-react';
import { calculateSolarPosition } from '@/lib/solar-position';
import { useGeolocation } from '@/hooks/use-geolocation';

export default function SundialApp() {
  const [time, setTime] = useState<Date | null>(null);
  const [isSimulating, setIsSimulating] = useState(false);
  const [simulatedTime, setSimulatedTime] = useState(12);
  const [showCastButton, setShowCastButton] = useState(false);
  const castTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const { coords } = useGeolocation();

  const handleInteraction = () => {
    setShowCastButton(true);
    if (castTimeoutRef.current) {
      clearTimeout(castTimeoutRef.current);
    }
    castTimeoutRef.current = setTimeout(() => {
      setShowCastButton(false);
    }, 3000);
  };

  useEffect(() => {
    const updateTime = () => setTime(new Date());
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  if (!time) {
    return <div className="min-h-screen bg-[#e0e5ec]" />;
  }

  const actualHours = time.getHours();
  const actualMinutes = time.getMinutes();
  const actualSeconds = time.getSeconds();
  
  const actualT = actualHours + actualMinutes / 60 + actualSeconds / 3600;
  const t = isSimulating ? simulatedTime : actualT;

  let displayHour = isSimulating ? Math.floor(simulatedTime) % 12 : actualHours % 12;
  if (displayHour === 0) displayHour = 12;

  // --- CELESTIAL POSITION MATH ---
  const hasSolarData = coords !== null;

  let dx: number, dy: number, elevation: number, isDaytime: boolean;
  let solarAzimuth = 0, solarAltitude = 0;

  if (hasSolarData) {
    // SOLAR PATH: Use real sun position
    const solarDate = isSimulating
      ? (() => {
          const d = new Date(time!);
          d.setHours(Math.floor(simulatedTime), Math.round((simulatedTime % 1) * 60), 0, 0);
          return d;
        })()
      : time!;

    const { azimuth, altitude } = calculateSolarPosition(solarDate, coords.latitude, coords.longitude);
    solarAzimuth = azimuth;
    solarAltitude = altitude;

    // isDaytime from real altitude (INTG-03)
    isDaytime = altitude > 0;

    if (isDaytime) {
      // Daytime solar path: use real azimuth for shadow direction
      // Shadow falls opposite the sun: shadow angle = sun azimuth + 180
      // Screen coords: x-right (+), y-down (+)
      // For meteorological convention: dx = sin(angle), dy = -cos(angle)
      const shadowAzimuthRad = ((azimuth + 180) % 360) * Math.PI / 180;
      dx = Math.sin(shadowAzimuthRad);
      dy = -Math.cos(shadowAzimuthRad);

      // Elevation: normalize altitude from degrees [0, 90] to [0, 1] (INTG-02)
      elevation = altitude / 90;
    } else {
      // Nighttime with coords: sun is below horizon, use existing moon arc
      const nightT = t < 6 ? t + 24 : t;
      const celestialAngleRad = ((nightT - 18) / 12) * Math.PI;
      const shadowAngleRad = celestialAngleRad + Math.PI;
      dx = Math.cos(shadowAngleRad);
      dy = Math.sin(shadowAngleRad);
      elevation = Math.max(0, Math.sin(celestialAngleRad));
    }
  } else {
    // FALLBACK PATH: Time-only arc (existing behavior, unchanged)
    isDaytime = t >= 6 && t < 18;

    let celestialAngleRad;
    if (isDaytime) {
      celestialAngleRad = ((t - 6) / 12) * Math.PI;
    } else {
      const nightT = t < 6 ? t + 24 : t;
      celestialAngleRad = ((nightT - 18) / 12) * Math.PI;
    }

    const shadowAngleRad = celestialAngleRad + Math.PI;
    dx = Math.cos(shadowAngleRad);
    dy = Math.sin(shadowAngleRad);
    elevation = Math.max(0, Math.sin(celestialAngleRad));
  }

  // Shadow length approaches infinity as elevation approaches 0
  const minShadowLength = 5; // vmin
  const shadowLength = minShadowLength + Math.pow(1 - elevation, 3) * 150; // vmin

  // Fade out shadow when celestial body is very low
  const opacityMultiplier = Math.min(1, elevation * 8);

  // --- SHADOW GENERATION (AO + Penumbra) ---
  const castShadowParts = [];

  // Helper: linear interpolation between two RGB triplets
  const lerpRgb = (warm: [number, number, number], cool: [number, number, number], f: number): string => {
    const r = Math.round(warm[0] + (cool[0] - warm[0]) * f);
    const g = Math.round(warm[1] + (cool[1] - warm[1]) * f);
    const b = Math.round(warm[2] + (cool[2] - warm[2]) * f);
    return `${r}, ${g}, ${b}`;
  };

  // altFactor: 0 at horizon (warm amber), 1 at 45+ deg altitude (cool blue-grey)
  const altFactor = hasSolarData && isDaytime
    ? Math.min(1, Math.max(0, solarAltitude / 45))
    : 1; // fallback = cool (existing behavior)

  const warmShadow: [number, number, number] = [180, 110, 40];
  const coolShadow: [number, number, number] = [10, 20, 40];
  const warmAo: [number, number, number] = [120, 60, 10];
  const coolAo: [number, number, number] = [0, 5, 15];

  // Colors based on day/night, with altitude-driven temperature shift during daytime
  const aoColor = isDaytime ? lerpRgb(warmAo, coolAo, altFactor) : '180, 210, 255';
  const shadowColor = isDaytime ? lerpRgb(warmShadow, coolShadow, altFactor) : '200, 230, 255';
  const shadowBlendMode = isDaytime ? 'soft-light' : 'overlay';
  
  // 1. Ambient Occlusion (Contact Shadow)
  // Tight, dark (or glowing) blur at the base to ground the object
  castShadowParts.push(`0vmin 0vmin 1.5vmin rgba(${aoColor}, ${0.9 * opacityMultiplier})`);
  castShadowParts.push(`${(dx * 0.5).toFixed(2)}vmin ${(dy * 0.5).toFixed(2)}vmin 2.5vmin rgba(${aoColor}, ${0.7 * opacityMultiplier})`);

  // 2. Directional Shadow with Penumbra
  const numSteps = 60; // Higher number of steps for smooth, long penumbra
  
  for (let i = 1; i <= numSteps; i++) {
    const progress = i / numSteps;
    
    // Ease-out progression: more steps concentrated near the base for smoothness
    const easeProgress = 1 - Math.pow(1 - progress, 2.5); 
    
    const distance = easeProgress * shadowLength;
    const x = (dx * distance).toFixed(2);
    const y = (dy * distance).toFixed(2);
    
    // Penumbra: Blur increases significantly with distance (soft edges)
    const blur = (distance * 0.15 + 0.5).toFixed(2);
    
    // Opacity fades out smoothly. Nighttime glow is softer.
    const baseOpacity = isDaytime ? 0.8 : 0.5; // Amped up opacity for softer blend modes
    const stepOpacity = (baseOpacity * Math.pow(1 - progress, 1.5) * opacityMultiplier).toFixed(3);
    
    castShadowParts.push(`${x}vmin ${y}vmin ${blur}vmin rgba(${shadowColor}, ${stepOpacity})`);
  }

  const castShadow = castShadowParts.join(', ');

  // --- OBJECT HIGHLIGHTS & VOLUME ---
  const highlightParts = [];
  const highlightColor = isDaytime ? '255, 255, 255' : '200, 230, 255';
  
  // Celestial body hitting the edge
  highlightParts.push(`${(-dx * 0.6).toFixed(2)}vmin ${(-dy * 0.6).toFixed(2)}vmin 1vmin rgba(${highlightColor}, ${0.95 * opacityMultiplier})`);
  highlightParts.push(`${(-dx * 0.2).toFixed(2)}vmin ${(-dy * 0.2).toFixed(2)}vmin 0.3vmin rgba(${highlightColor}, ${0.95 * opacityMultiplier})`);
  
  // Core shadow on the unlit side of the number itself
  if (isDaytime) {
    highlightParts.push(`${(dx * 0.8).toFixed(2)}vmin ${(dy * 0.8).toFixed(2)}vmin 1.5vmin rgba(0, 0, 0, ${0.4 * opacityMultiplier})`);
  } else {
    highlightParts.push(`${(dx * 0.8).toFixed(2)}vmin ${(dy * 0.8).toFixed(2)}vmin 1.5vmin rgba(0, 5, 15, ${0.8 * opacityMultiplier})`);
  }
  const volumeShadow = highlightParts.join(', ');

  // --- COLORS & LIGHTING ---
  const blendColors = (c1: string, c2: string, factor: number) => {
    const hex2rgb = (hex: string) => {
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);
      return [r, g, b];
    };
    const rgb1 = hex2rgb(c1);
    const rgb2 = hex2rgb(c2);
    const r = Math.round(rgb1[0] + (rgb2[0] - rgb1[0]) * factor);
    const g = Math.round(rgb1[1] + (rgb2[1] - rgb1[1]) * factor);
    const b = Math.round(rgb1[2] + (rgb2[2] - rgb1[2]) * factor);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  };

  const PALETTES = {
    night: { center: '#1a252f', mid: '#111820', edge: '#080c10', text: '#2c3e50' },
    sunrise: { center: '#ffe4c4', mid: '#dcb494', edge: '#8a9ba8', text: '#f0e6d8' },
    day: { center: '#ffffff', mid: '#e0e5ec', edge: '#b8c2cc', text: '#e8ecef' },
    sunset: { center: '#ffcda8', mid: '#c9967d', edge: '#7a8b99', text: '#ebdcd3' }
  };

  const blendPalette = (p1: any, p2: any, factor: number) => ({
    center: blendColors(p1.center, p2.center, factor),
    mid: blendColors(p1.mid, p2.mid, factor),
    edge: blendColors(p1.edge, p2.edge, factor),
    text: blendColors(p1.text, p2.text, factor)
  });

  let currentPalette;
  if (t >= 3 && t < 6) {
    currentPalette = blendPalette(PALETTES.night, PALETTES.sunrise, (t - 3) / 3);
  } else if (t >= 6 && t < 9) {
    currentPalette = blendPalette(PALETTES.sunrise, PALETTES.day, (t - 6) / 3);
  } else if (t >= 9 && t < 15) {
    currentPalette = PALETTES.day;
  } else if (t >= 15 && t < 18) {
    currentPalette = blendPalette(PALETTES.day, PALETTES.sunset, (t - 15) / 3);
  } else if (t >= 18 && t < 21) {
    currentPalette = blendPalette(PALETTES.sunset, PALETTES.night, (t - 18) / 3);
  } else {
    currentPalette = PALETTES.night;
  }

  const bgCenter = currentPalette.center;
  const bgMid = currentPalette.mid;
  const bgEdge = currentPalette.edge;
  const textColor = currentPalette.text;

  // Calculate gradient center based on celestial position
  let celestialX: number, celestialY: number;
  if (hasSolarData) {
    // Sun position on gradient: azimuth drives horizontal, altitude drives vertical
    const azRad = solarAzimuth * Math.PI / 180;
    celestialX = 50 + Math.sin(azRad) * 40;
    celestialY = 50 - Math.max(0, solarAltitude / 90) * 40;
  } else {
    const celestialAngleRad = isDaytime
      ? ((t - 6) / 12) * Math.PI
      : (((t < 6 ? t + 24 : t) - 18) / 12) * Math.PI;
    celestialX = 50 + Math.cos(celestialAngleRad) * 40;
    celestialY = 50 + Math.sin(celestialAngleRad) * 40 - (elevation * 40);
  }

  const simHours = Math.floor(simulatedTime);
  const simMinutes = Math.floor((simulatedTime % 1) * 60);
  const simTimeDisplay = `${simHours.toString().padStart(2, '0')}:${simMinutes.toString().padStart(2, '0')}`;

  const isIOS = typeof navigator !== 'undefined' && /iPad|iPhone|iPod/.test(navigator.userAgent);

  const handleCast = async () => {
    if (isIOS) {
      alert(
        'To display on your TV:\n\n' +
        '1. Swipe down from the top-right corner to open Control Center\n' +
        '2. Tap "Screen Mirroring"\n' +
        '3. Select your Apple TV or AirPlay display\n\n' +
        'The entire screen (including this sundial) will appear on your TV.'
      );
      return;
    }

    if ('PresentationRequest' in window) {
      try {
        const castUrl = new URL(window.location.href);
        if (coords) {
          castUrl.searchParams.set('lat', coords.latitude.toString());
          castUrl.searchParams.set('lon', coords.longitude.toString());
        }
        const request = new (window as any).PresentationRequest([castUrl.toString()]);
        await request.start();
      } catch (err: any) {
        if (err.name === 'NotFoundError' || err.message?.includes('No screens found')) {
          alert('No cast-compatible screens found on your network. Please ensure your TV or smart display is turned on and connected to the same Wi-Fi network.');
        } else if (err.name !== 'NotAllowedError') {
          console.error('Error starting cast:', err);
          alert("Failed to start casting. You can also try using the 'Cast...' option from your browser's main menu (⋮ → Cast).");
        }
      }
    } else {
      alert(
        'Casting is not supported in this browser.\n\n' +
        'On Android: Open this page in Chrome, tap ⋮ menu → "Cast"\n' +
        'On desktop: Use Chrome and select "Cast..." from the menu'
      );
    }
  };

  const minuteFraction = isSimulating 
    ? (simulatedTime % 1) 
    : (actualMinutes + actualSeconds / 60) / 60;
  const minuteAngle = minuteFraction * 360;

  return (
    <div 
      className="h-screen flex flex-col items-center justify-center overflow-hidden transition-colors duration-1000"
      style={{
        background: `radial-gradient(circle at ${celestialX}% ${celestialY}%, ${bgCenter} 0%, ${bgMid} 50%, ${bgEdge} 100%)`
      }}
      onPointerDown={handleInteraction}
      onMouseMove={handleInteraction}
    >
      {/* Subtle Noise Texture */}
      <div 
        className="absolute inset-0 pointer-events-none z-0 opacity-[0.04] mix-blend-overlay"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
          backgroundSize: '200px 200px',
          backgroundRepeat: 'repeat'
        }}
      />

      <AnimatePresence>
        {showCastButton && (
          <motion.button
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={(e) => {
              e.stopPropagation();
              handleCast();
            }}
            className="absolute top-8 right-8 z-20 p-3 rounded-full hover:bg-white/10 transition-colors"
            style={{ color: textColor, transition: 'color 1s ease' }}
            title="Cast to TV"
          >
            <Cast size={24} />
          </motion.button>
        )}
      </AnimatePresence>

      <div className="relative flex items-center justify-center w-full flex-1">
        {/* Number container — shifted up to compensate for Playfair Display's
             descender metrics pushing digits below visual center */}
        <div style={{ transform: 'translateY(-0.09em)', fontSize: '45vmin' }}>
          {/* Cast Shadow Layer (Multiply/Screen Blend Mode for realism) */}
          <motion.div
            className="absolute inset-0 font-black leading-none select-none"
            style={{
              color: 'transparent',
              textShadow: castShadow,
              fontFamily: 'var(--font-serif)',
              mixBlendMode: shadowBlendMode as any,
              zIndex: 1
            }}
          >
            {displayHour}
          </motion.div>

          {/* Physical Object Layer (Text with volume/highlights) */}
          <motion.div
            className="relative font-black leading-none select-none"
            style={{
              color: textColor,
              textShadow: volumeShadow,
              fontFamily: 'var(--font-serif)',
              zIndex: 2,
              transition: 'color 1s ease'
            }}
          >
            {displayHour}
          </motion.div>
        </div>

        {/* Minute Indicator */}
        <div
          className="absolute rounded-full"
          style={{
            width: '1.2vmin',
            height: '1.2vmin',
            backgroundColor: textColor,
            top: '50%',
            left: '50%',
            transform: `translate(-50%, -50%) rotate(${minuteAngle}deg) translateY(-34vmin)`,
            boxShadow: `0 0 1.5vmin rgba(${highlightColor}, ${0.8 * opacityMultiplier})`,
            zIndex: 3,
            transition: 'background-color 1s ease'
          }}
        />
      </div>

      {isSimulating && (
        <div className="absolute bottom-24 w-64 max-w-[80vw] flex flex-col items-center gap-2 z-20" style={{ color: textColor, transition: 'color 1s ease' }}>
          <div className="font-mono text-sm">
            Simulated Time: {simTimeDisplay}
          </div>
          <input 
            type="range" 
            min="0" 
            max="23.99" 
            step="0.05" 
            value={simulatedTime}
            onChange={(e) => setSimulatedTime(parseFloat(e.target.value))}
            className="w-full h-2 bg-white/30 rounded-lg appearance-none cursor-pointer accent-white"
          />
        </div>
      )}

      <button 
        onClick={() => setIsSimulating(!isSimulating)}
        className="absolute bottom-8 font-mono text-sm tracking-widest transition-colors px-4 py-2 rounded-full hover:bg-white/10 z-20"
        style={{ color: textColor, transition: 'color 1s ease' }}
      >
        {isSimulating ? 'BACK TO REAL TIME' : time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
      </button>
    </div>
  );
}
