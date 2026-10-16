package com.cycloedge.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = ElectricGreen,
    secondary = ElectricBlue,
    tertiary = NeonYellow,
    background = PureBlack,
    surface = DarkSurface,
    onPrimary = PureBlack,
    onSecondary = PureWhite,
    onTertiary = PureBlack,
    onBackground = PureWhite,
    onSurface = PureWhite
)

@Composable
fun CycloEdgeTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = CycloTypography,
        content = content
    )
}

