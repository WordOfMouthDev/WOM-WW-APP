import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
#if DEBUG
import FirebaseAppCheck
#endif

class FirebaseConfig {
    
    static func configure() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Firestore settings to avoid BloomFilter warnings
        configureFirestore()
        
        #if DEBUG
        // Only enable AppCheck in debug if needed
        // configureAppCheck()
        print("🔥 Firebase configured for DEBUG mode")
        #else
        // Configure AppCheck for production
        configureAppCheckForProduction()
        print("🔥 Firebase configured for PRODUCTION mode")
        #endif
    }
    
    private static func configureFirestore() {
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        
        // Configure settings to reduce warnings
        let cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited)
        )
        settings.cacheSettings = cacheSettings
        
        db.settings = settings
    }
    
    #if DEBUG
    private static func configureAppCheck() {
        // Only use this if you need AppCheck in development
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // Set debug token
        UserDefaults.standard.set(
            "DE8D62B1-A82D-4774-848A-D90330C566F6",
            forKey: "FIRAppCheckDebugToken"
        )
    }
    #endif
    
    #if !DEBUG
    private static func configureAppCheckForProduction() {
        // Configure AppCheck for production with App Attest
        let providerFactory = DefaultAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
    }
    #endif
    
    static func enableFirestoreLogging(_ enabled: Bool = false) {
        #if DEBUG
        if enabled {
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
        } else {
            FirebaseConfiguration.shared.setLoggerLevel(.error)
        }
        #endif
    }
}
