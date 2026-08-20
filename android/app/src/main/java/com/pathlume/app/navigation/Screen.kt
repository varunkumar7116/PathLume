package com.pathlume.app.navigation

sealed class Screen(val route: String) {
    object Splash : Screen("splash")
    object Home : Screen("home")
    object QRScanner : Screen("qr_scanner")
    object SiteLoading : Screen("site_loading/{siteId}") {
        fun createRoute(siteId: String) = "site_loading/$siteId"
    }
    object Localization : Screen("localization/{siteId}") {
        fun createRoute(siteId: String) = "localization/$siteId"
    }
    object DestinationSearch : Screen("destination_search/{siteId}") {
        fun createRoute(siteId: String) = "destination_search/$siteId"
    }
    object DestinationDetails : Screen("destination_details/{siteId}/{destinationId}") {
        fun createRoute(siteId: String, destinationId: String) = "destination_details/$siteId/$destinationId"
    }
    object ARNavigation : Screen("ar_navigation/{siteId}/{destinationId}") {
        fun createRoute(siteId: String, destinationId: String) = "ar_navigation/$siteId/$destinationId"
    }
    object Arrival : Screen("arrival/{destinationName}") {
        fun createRoute(destinationName: String) = "arrival/$destinationName"
    }
    object Settings : Screen("settings")
    object DeveloperDebug : Screen("debug")
    object FieldTest : Screen("field_test")
}
