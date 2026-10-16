package com.cycloedge.app.ui.cockpit

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cycloedge.app.ui.theme.*

@Composable
fun MetricGridCard(
    label: String,
    value: String,
    unit: String = "",
    badgeText: String? = null,
    badgeColor: Color = ElectricGreen,
    valueColor: Color = PureWhite,
    valueStyle: TextStyle = CycloTypography.displayMedium,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(CardBackground, RoundedCornerShape(10.dp))
            .border(1.dp, CardBorder, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth()
        ) {
            // Header Row: Label + Optional Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = label.uppercase(),
                    style = CycloTypography.labelSmall,
                    color = TextMuted
                )
                if (badgeText != null) {
                    Box(
                        modifier = Modifier
                            .background(badgeColor.copy(alpha = 0.2f), RoundedCornerShape(4.dp))
                            .border(1.dp, badgeColor, RoundedCornerShape(4.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = badgeText,
                            color = badgeColor,
                            fontSize = 10.sp,
                            style = CycloTypography.labelSmall
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Value + Unit
            Row(
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    text = value,
                    style = valueStyle,
                    color = valueColor
                )
                if (unit.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = unit,
                        style = CycloTypography.labelSmall,
                        color = TextMuted,
                        modifier = Modifier.padding(bottom = 6.dp)
                    )
                }
            }
        }
    }
}

