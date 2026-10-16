package com.cycloedge.app.ui.cockpit

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.cycloedge.app.ui.theme.*

@Composable
fun RainLockOverlay(
    isLocked: Boolean,
    onUnlockRequested: () -> Unit,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible = isLocked,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.85f))
                .pointerInput(Unit) {
                    detectTapGestures(
                        onLongPress = {
                            onUnlockRequested()
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier
                    .padding(32.dp)
                    .background(CardBackground, RoundedCornerShape(16.dp))
                    .padding(24.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .background(NeonYellow.copy(alpha = 0.2f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = "Layar Terkunci",
                        tint = NeonYellow,
                        modifier = Modifier.size(36.dp)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "RAIN & SWEAT LOCK AKTIF",
                    style = CycloTypography.labelSmall,
                    color = PureWhite
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Layar sentuh dikunci terhadap air hujan dan keringat.\nTahan layar selama 2 detik untuk membuka.",
                    style = CycloTypography.bodyMedium,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

