import * as React from "react"

export type GeolocationStatus = 'idle' | 'pending' | 'granted' | 'denied' | 'unavailable';

export interface UseGeolocationReturn {
  coords: { latitude: number; longitude: number } | null;
  status: GeolocationStatus;
}

export function useGeolocation(): UseGeolocationReturn {
  const [coords, setCoords] = React.useState<{ latitude: number; longitude: number } | null>(null);
  const [status, setStatus] = React.useState<GeolocationStatus>('idle');
  const requestedRef = React.useRef(false);

  React.useEffect(() => {
    if (typeof window === 'undefined' || !navigator.geolocation) {
      setStatus('unavailable');
      return;
    }

    // Check for coords passed via URL params (used by Presentation API cast displays)
    const searchParams = new URLSearchParams(window.location.search);
    const latParam = searchParams.get('lat');
    const lonParam = searchParams.get('lon');
    if (latParam !== null && lonParam !== null) {
      const latitude = parseFloat(latParam);
      const longitude = parseFloat(lonParam);
      if (!isNaN(latitude) && !isNaN(longitude)) {
        setCoords({ latitude, longitude });
        setStatus('granted');
        return;
      }
    }

    if (requestedRef.current) return;
    requestedRef.current = true;

    setStatus('pending');

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        setCoords({ latitude, longitude });
        setStatus('granted');
      },
      (error) => {
        if (error.code === 1) {
          // PERMISSION_DENIED — permanent for this session
          setStatus('denied');
        } else if (error.code === 2) {
          // POSITION_UNAVAILABLE
          setStatus('unavailable');
        } else if (error.code === 3) {
          // TIMEOUT
          setStatus('unavailable');
        }
      },
      { timeout: 10000, maximumAge: 300000 }
    );
  }, []);

  return { coords, status };
}
