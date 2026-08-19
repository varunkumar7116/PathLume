package com.pathlume.app.presentation.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = SkyBlue,
    secondary = BluePrimary,
    tertiary = AccentGreen,
    background = NavyDark,
    surface = CardDark,
    onPrimary = NavyDark,
    onSecondary = TextMain,
    onBackground = TextMain,
    onSurface = TextMain
)

@Composable
fun PathLumeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography,
        content = content
    )
}
