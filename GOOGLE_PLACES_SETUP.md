# Google Places API Setup for Business Images

To enable business images in your app, you need to set up Google Places API:

## Step 1: Get Google Places API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - **Places API**
   - **Places API (New)**
   - **Geocoding API**
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy your API key

## Step 2: Configure API Key in App

1. Open `WOM-APP/Core/Services/BusinessSearchManager.swift`
2. Replace `"YOUR_GOOGLE_PLACES_API_KEY"` with your actual API key:

```swift
private let googlePlacesAPIKey = "YOUR_ACTUAL_API_KEY_HERE"
```

## Step 3: Restrict API Key (Recommended)

1. In Google Cloud Console, click on your API key
2. Under "Application restrictions":
   - Select "iOS apps"
   - Add your bundle identifier (e.g., com.yourcompany.womapp)
3. Under "API restrictions":
   - Select "Restrict key"
   - Choose: Places API, Places API (New), Geocoding API

## How It Works

The app now fetches business images in this order:

1. **Google Places API**: Real business photos from Google's database
2. **Placeholder Images**: Colorful placeholder images with business name if no real photo available

## Features

- ✅ **Real business photos** from Google Places
- ✅ **Batched processing** to respect API limits
- ✅ **Fallback placeholders** for businesses without photos
- ✅ **Concurrent image fetching** for better performance
- ✅ **Rate limiting** to avoid API quota issues

## API Costs

Google Places API pricing (as of 2024):
- **Nearby Search**: $32 per 1,000 requests
- **Place Details**: $17 per 1,000 requests  
- **Place Photos**: $7 per 1,000 requests

For development, Google provides $200 free credit monthly.

## Without API Key

If you don't set up the API key, the app will automatically use colorful placeholder images based on the business name.

