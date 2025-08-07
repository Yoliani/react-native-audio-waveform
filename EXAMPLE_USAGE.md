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

## Using Source Object with HTTPS URLs (Fixed)

### Remote Audio File with Authentication

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      source={{
        uri: "https://api.example.com/audio/protected-file.mp3",
        headers: {
          "Authorization": "Bearer your_jwt_token_here",
          "X-API-Key": "your_api_key",
          "User-Agent": "YourApp/1.0"
        }
      }}
      volume={1.0}
      onError={(error) => {
        console.error('Audio loading failed:', error);
      }}
      // ... other props
    />
  );
};
```

### Public HTTPS Audio File

```tsx
import { Waveform } from 'react-native-audio-waveform';

const MyComponent = () => {
  return (
    <Waveform
      mode="static"
      source={{
        uri: "https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3"
      }}
      volume={1.0}
      onError={(error) => {
        console.error('Audio loading failed:', error);
      }}
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

## Troubleshooting HTTPS URLs

### Common Issues and Solutions

1. **Network Security (Android)**
   - Make sure your `android/app/src/main/AndroidManifest.xml` allows cleartext traffic if needed:
   
   ```xml
   <application
     android:usesCleartextTraffic="true"
     ... >
   ```

2. **CORS Issues (Web-like behavior)**
   - Ensure the audio server supports the necessary CORS headers
   - Some audio servers may reject requests without proper User-Agent headers

3. **Authentication Headers**
   - For authenticated requests, make sure your headers include all required authentication
   - Common headers: `Authorization`, `X-API-Key`, `User-Agent`

4. **iOS App Transport Security**
   - For HTTP (non-HTTPS) URLs, you may need to configure ATS in your `Info.plist`:
   
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
     <key>NSAllowsArbitraryLoads</key>
     <true/>
   </dict>
   ```

5. **Timeout Issues**
   - The library has built-in timeouts (30-60 seconds) for loading remote audio
   - Large audio files or slow networks may cause timeouts
   - Consider using streaming-friendly formats (M4A, MP3) instead of uncompressed formats

### Supported Audio Formats for HTTPS

- **iOS**: MP3, M4A, WAV, AAC (via AVPlayer for remote URLs)
- **Android**: MP3, M4A, WAV, AAC, OGG (via MediaExtractor)

### Performance Tips

- Use compressed formats (MP3, M4A) for better loading performance
- Consider implementing retry logic for network failures
- Cache frequently accessed audio files locally when possible
