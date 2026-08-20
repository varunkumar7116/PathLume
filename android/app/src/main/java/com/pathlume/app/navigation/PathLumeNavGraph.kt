package com.pathlume.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Vector3D
import com.pathlume.app.presentation.ar.ARNavigationScreen
import com.pathlume.app.presentation.arrival.ArrivalScreen
import com.pathlume.app.presentation.debug.DeveloperDebugScreen
import com.pathlume.app.presentation.destinations.DestinationDetailsScreen
import com.pathlume.app.presentation.destinations.DestinationSearchScreen
import com.pathlume.app.presentation.home.HomeScreen
import com.pathlume.app.presentation.localization.LocalizationScreen
import com.pathlume.app.presentation.qr.QRScannerScreen
import com.pathlume.app.presentation.settings.SettingsScreen
import com.pathlume.app.presentation.siteloading.SiteLoadingScreen
import com.pathlume.app.presentation.splash.SplashScreen

@Composable
fun PathLumeNavGraph(
    navController: NavHostController,
    startDestination: String = Screen.Splash.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // 1. Splash
        composable(Screen.Splash.route) {
            SplashScreen(
                onSplashFinished = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                }
            )
        }

        // 2. Home
        composable(Screen.Home.route) {
            HomeScreen(
                onScanQRClicked = {
                    navController.navigate(Screen.QRScanner.route)
                },
                onSiteSelected = { siteId ->
                    navController.navigate(Screen.SiteLoading.createRoute(siteId))
                },
                onSettingsClicked = {
                    navController.navigate(Screen.Settings.route)
                }
            )
        }

        // 3. QR Scanner
        composable(Screen.QRScanner.route) {
            QRScannerScreen(
                onSiteScanned = { siteId ->
                    navController.navigate(Screen.SiteLoading.createRoute(siteId)) {
                        popUpTo(Screen.QRScanner.route) { inclusive = true }
                    }
                },
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }

        // 4. Site Loading (Supports Deep Links)
        composable(
            route = Screen.SiteLoading.route,
            arguments = listOf(navArgument("siteId") { type = NavType.StringType }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "https://pathlume.app/s/{siteId}" },
                navDeepLink { uriPattern = "pathlume://site/{siteId}" }
            )
        ) { backStackEntry ->
            val siteId = backStackEntry.arguments?.getString("siteId") ?: "demo_site"
            SiteLoadingScreen(
                siteId = siteId,
                onSiteLoaded = { site ->
                    navController.navigate(Screen.Localization.createRoute(site.siteId))
                },
                onBackClicked = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                }
            )
        }

        // 5. Localization
        composable(
            route = Screen.Localization.route,
            arguments = listOf(navArgument("siteId") { type = NavType.StringType })
        ) { backStackEntry ->
            val siteId = backStackEntry.arguments?.getString("siteId") ?: "demo_site"
            LocalizationScreen(
                siteId = siteId,
                onLocalized = {
                    navController.navigate(Screen.DestinationSearch.createRoute(siteId)) {
                        popUpTo(Screen.Localization.route) { inclusive = true }
                    }
                },
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }

        // 6. Destination Search
        composable(
            route = Screen.DestinationSearch.route,
            arguments = listOf(navArgument("siteId") { type = NavType.StringType })
        ) { backStackEntry ->
            val siteId = backStackEntry.arguments?.getString("siteId") ?: "demo_site"
            DestinationSearchScreen(
                siteId = siteId,
                onDestinationSelected = { dest ->
                    navController.navigate(Screen.DestinationDetails.createRoute(siteId, dest.id))
                },
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }

        // 7. Destination Details
        composable(
            route = Screen.DestinationDetails.route,
            arguments = listOf(
                navArgument("siteId") { type = NavType.StringType },
                navArgument("destinationId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val siteId = backStackEntry.arguments?.getString("siteId") ?: "demo_site"
            val destId = backStackEntry.arguments?.getString("destinationId") ?: "d1"
            
            val destinationMap = mapOf(
                "d1" to Destination("d1", "Main Library & Research Center", "b1", "floor_1", Vector3D(10f, 0f, 5f), "Academic"),
                "d2" to Destination("d2", "Executive Conference Room 201", "b1", "floor_1", Vector3D(15f, 0f, 12f), "Office"),
                "d3" to Destination("d3", "Student Reception & Help Desk", "b1", "floor_0", Vector3D(2f, 0f, 2f), "Service"),
                "d4" to Destination("d4", "Central Cafeteria & Lounge", "b1", "floor_0", Vector3D(-8f, 0f, 6f), "Dining"),
                "d5" to Destination("d5", "Innovation & Robotics Lab", "b2", "floor_0", Vector3D(-12f, 0f, -10f), "Lab")
            )
            val destination = destinationMap[destId] ?: Destination(destId, "Destination ($destId)", "b1", "floor_0", Vector3D(5f, 0f, 5f), "General")

            DestinationDetailsScreen(
                destination = destination,
                onStartNavigation = {
                    navController.navigate(Screen.ARNavigation.createRoute(siteId, destId))
                },
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }

        // 8. AR Navigation
        composable(
            route = Screen.ARNavigation.route,
            arguments = listOf(
                navArgument("siteId") { type = NavType.StringType },
                navArgument("destinationId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val destId = backStackEntry.arguments?.getString("destinationId") ?: "d1"

            val destinationMap = mapOf(
                "d1" to Destination("d1", "Main Library & Research Center", "b1", "floor_1", Vector3D(10f, 0f, 5f), "Academic"),
                "d2" to Destination("d2", "Executive Conference Room 201", "b1", "floor_1", Vector3D(15f, 0f, 12f), "Office"),
                "d3" to Destination("d3", "Student Reception & Help Desk", "b1", "floor_0", Vector3D(2f, 0f, 2f), "Service"),
                "d4" to Destination("d4", "Central Cafeteria & Lounge", "b1", "floor_0", Vector3D(-8f, 0f, 6f), "Dining"),
                "d5" to Destination("d5", "Innovation & Robotics Lab", "b2", "floor_0", Vector3D(-12f, 0f, -10f), "Lab")
            )
            val destination = destinationMap[destId] ?: Destination(destId, "Destination ($destId)", "b1", "floor_0", Vector3D(5f, 0f, 5f), "General")

            ARNavigationScreen(
                destination = destination,
                onArrived = {
                    navController.navigate(Screen.Arrival.createRoute(destination.name)) {
                        popUpTo(Screen.ARNavigation.route) { inclusive = true }
                    }
                },
                onCloseClicked = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                }
            )
        }

        // 9. Arrival
        composable(
            route = Screen.Arrival.route,
            arguments = listOf(navArgument("destinationName") { type = NavType.StringType })
        ) { backStackEntry ->
            val destName = backStackEntry.arguments?.getString("destinationName") ?: "Destination"
            ArrivalScreen(
                destinationName = destName,
                onDoneClicked = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                }
            )
        }

        // 10. Settings
        composable(Screen.Settings.route) {
            SettingsScreen(
                onOpenDiagnostics = {
                    navController.navigate(Screen.DeveloperDebug.route)
                },
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }

        // 11. Developer Diagnostics
        composable(Screen.DeveloperDebug.route) {
            DeveloperDebugScreen(
                onBackClicked = {
                    navController.popBackStack()
                }
            )
        }
    }
}
