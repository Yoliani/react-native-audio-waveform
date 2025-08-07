# Audio Source Usage Examples

This library now supports both path and source objects for audio playback. Here are the usage examples:

## Using Path (Legacy, still supported)

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      path="/path/to/audio/file.mp3"
      volume={1.0}
      // ... other props
    />
  );
};
```

## Using Source Object (New)

### Local File

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      source={{
        uri: "file:///path/to/local/audio/file.mp3"
      }}
      volume={1.0}
      // ... other props
    />
  );
};
```

### HTTP/HTTPS URL

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      source={{
        uri: "https://example.com/audio/file.mp3"
      }}
      volume={1.0}
      // ... other props
    />
  );
};
```

### HTTP/HTTPS URL with Headers

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      source={{
        uri: "https://example.com/protected/audio/file.mp3",
        headers: {
          "Authorization": "Bearer your_token_here",
          "Custom-Header": "custom_value"
        }
      }}
      volume={1.0}
      // ... other props
    />
  );
};
```

## TypeScript Types

The source object follows this interface:

```typescript
interface IAudioSource {
  uri: string;
  headers?: Record<string, string>;
}
```

## Migration Guide

If you're migrating from using `path`, you can either:

1. Keep using `path` (no changes needed)
2. Replace `path` with `source.uri`:
   - `path="/path/to/file.mp3"` becomes `source={{ uri: "/path/to/file.mp3" }}`
3. Add headers if needed for authenticated URLs:

   ```tsx
   source={{
     uri: "https://api.example.com/audio/file.mp3",
     headers: { "Authorization": "Bearer token" }
   }}
   ```

## Notes

- Either `path` or `source` must be provided for static mode
- You cannot use both `path` and `source` at the same time
- Headers are only applicable for HTTP/HTTPS URLs
- The implementation handles both local files and remote URLs automatically
