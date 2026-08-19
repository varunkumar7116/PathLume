package com.pathlume.app.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import com.pathlume.app.presentation.home.HomeScreen
import com.pathlume.app.presentation.qr.QRScannerScreen
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
        // 1. Splash Screen
        composable(Screen.Splash.route) {
            SplashScreen(
                onSplashFinished = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                }
            )
        }

        // 2. Home Screen
        composable(Screen.Home.route) {
            HomeScreen(
                onScanQRClicked = {
                    navController.navigate(Screen.QRScanner.route)
                },
                onSiteSelected = { siteId ->
                    navController.navigate(Screen.SiteLoading.createRoute(siteId))
                },
                onSettingsClicked = {
                    // Settings screen
                }
            )
        }

        // 3. QR Scanner Screen
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

        // 4. Site Loading Screen (Supports Deep Links: https://pathlume.app/s/{siteId} and pathlume://site/{siteId})
        composable(
            route = Screen.SiteLoading.route,
            arguments = listOf(
                navArgument("siteId") { type = NavType.StringType }
            ),
            deepLinks = listOf(
                navDeepLink { uriPattern = "https://pathlume.app/s/{siteId}" },
                navDeepLink { uriPattern = "pathlume://site/{siteId}" }
            )
        ) { backStackEntry ->
            val siteId = backStackEntry.arguments?.getString("siteId") ?: "demo_site"
            SiteLoadingScreen(
                siteId = siteId,
                onSiteLoaded = { site ->
                    // Proceed to localization or destination search
                },
                onBackClicked = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                }
            )
        }
    }
}
