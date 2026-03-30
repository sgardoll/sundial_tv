import { describe, it, expect, vi, afterEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { useGeolocation } from './use-geolocation';

function mockGeolocation(behavior: 'success' | 'denied' | 'unavailable' | 'timeout') {
  const getCurrentPosition = vi.fn((success: PositionCallback, error: PositionErrorCallback) => {
    if (behavior === 'success') {
      success({ coords: { latitude: 51.5, longitude: -0.1 } } as GeolocationPosition);
    } else if (behavior === 'denied') {
      error({ code: 1, message: 'User denied' } as GeolocationPositionError);
    } else if (behavior === 'unavailable') {
      error({ code: 2, message: 'Position unavailable' } as GeolocationPositionError);
    } else if (behavior === 'timeout') {
      error({ code: 3, message: 'Timeout' } as GeolocationPositionError);
    }
  });
  Object.defineProperty(navigator, 'geolocation', {
    value: { getCurrentPosition },
    writable: true,
    configurable: true,
  });
  return getCurrentPosition;
}

describe('useGeolocation', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('Test 1 (SSR safety): returns unavailable when navigator.geolocation is undefined', async () => {
    // Temporarily remove geolocation from navigator
    const originalGeolocation = navigator.geolocation;
    Object.defineProperty(navigator, 'geolocation', {
      value: undefined,
      writable: true,
      configurable: true,
    });

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('unavailable');
    });
    expect(result.current.coords).toBeNull();

    // Restore
    Object.defineProperty(navigator, 'geolocation', {
      value: originalGeolocation,
      writable: true,
      configurable: true,
    });
  });

  it('Test 2 (success path): returns coords and granted status after successful getCurrentPosition', async () => {
    mockGeolocation('success');

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('granted');
    });
    expect(result.current.coords).toEqual({ latitude: 51.5, longitude: -0.1 });
  });

  it('Test 3 (permission denied): returns denied status and null coords when error code is 1', async () => {
    mockGeolocation('denied');

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('denied');
    });
    expect(result.current.coords).toBeNull();
  });

  it('Test 4 (position unavailable): returns unavailable status and null coords when error code is 2', async () => {
    mockGeolocation('unavailable');

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('unavailable');
    });
    expect(result.current.coords).toBeNull();
  });

  it('Test 5 (timeout): returns unavailable status and null coords when error code is 3', async () => {
    mockGeolocation('timeout');

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('unavailable');
    });
    expect(result.current.coords).toBeNull();
  });

  it('Test 6 (one-shot): getCurrentPosition is called exactly once', async () => {
    const getCurrentPosition = mockGeolocation('success');

    const { result } = renderHook(() => useGeolocation());

    await waitFor(() => {
      expect(result.current.status).toBe('granted');
    });

    expect(getCurrentPosition).toHaveBeenCalledTimes(1);
  });
});
