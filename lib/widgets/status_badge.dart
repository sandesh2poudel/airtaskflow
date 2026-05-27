// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });

  factory StatusBadge.forPayment(String status) {
    switch (status) {
      case 'Paid':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF34D399),
          bgColor: AppColors.greenSoft,
          borderColor: AppColors.green.withOpacity(0.3),
        );
      case 'Partial':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFFBBF24),
          bgColor: AppColors.yellowSoft,
          borderColor: AppColors.yellow.withOpacity(0.3),
        );
      default:
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFF87171),
          bgColor: AppColors.redSoft,
          borderColor: AppColors.red.withOpacity(0.3),
        );
    }
  }

  factory StatusBadge.forLeadStatus(String status) {
    switch (status) {
      case 'Closed':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF34D399),
          bgColor: AppColors.greenSoft,
          borderColor: AppColors.green.withOpacity(0.3),
        );
      case 'In Talk':
      case 'Interested':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF60A5FA),
          bgColor: AppColors.accentSoft,
          borderColor: AppColors.accent.withOpacity(0.3),
        );
      case 'Follow Up':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFFBBF24),
          bgColor: AppColors.yellowSoft,
          borderColor: AppColors.yellow.withOpacity(0.3),
        );
      default:
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFF87171),
          bgColor: AppColors.redSoft,
          borderColor: AppColors.red.withOpacity(0.3),
        );
    }
  }

  factory StatusBadge.forTaskStatus(String status) {
    switch (status) {
      case 'Completed':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF34D399),
          bgColor: AppColors.greenSoft,
          borderColor: AppColors.green.withOpacity(0.3),
        );
      case 'Reviewed':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFA78BFA),
          bgColor: const Color(0x1A7C3AED),
          borderColor: const Color(0x337C3AED),
        );
      case 'Forwarded to Sales':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF60A5FA),
          bgColor: AppColors.accentSoft,
          borderColor: AppColors.accent.withOpacity(0.3),
        );
      case 'In Progress':
        return StatusBadge(
          label: status,
          textColor: const Color(0xFF06B6D4),
          bgColor: const Color(0x1A06B6D4),
          borderColor: const Color(0x3306B6D4),
        );
      default: // Pending
        return StatusBadge(
          label: status,
          textColor: const Color(0xFFFBBF24),
          bgColor: AppColors.yellowSoft,
          borderColor: AppColors.yellow.withOpacity(0.3),
        );
    }
  }

  factory StatusBadge.forAssign(String status) {
    if (status == 'Assigned') {
      return StatusBadge(
        label: status,
        textColor: const Color(0xFF34D399),
        bgColor: AppColors.greenSoft,
        borderColor: AppColors.green.withOpacity(0.3),
      );
    }
    return StatusBadge(
      label: status,
      textColor: const Color(0xFFFBBF24),
      bgColor: AppColors.yellowSoft,
      borderColor: AppColors.yellow.withOpacity(0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class DeadlineBadge extends StatelessWidget {
  final String dateStr;
  final int daysLeft;

  const DeadlineBadge({super.key, required this.dateStr, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (daysLeft < 0) {
      color = AppColors.red;
      label = 'Overdue ${daysLeft.abs()}d';
    } else if (daysLeft == 0) {
      color = AppColors.red;
      label = 'Due Today';
    } else if (daysLeft <= 2) {
      color = AppColors.yellow;
      label = '${daysLeft}d left';
    } else if (daysLeft <= 7) {
      color = AppColors.green;
      label = '${daysLeft}d left';
    } else {
      color = AppColors.darkText3;
      label = '${daysLeft}d';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(dateStr,
          style: const TextStyle(fontSize: 11.5, color: AppColors.darkText2),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority == 'High'
        ? AppColors.red
        : priority == 'Medium'
            ? AppColors.yellow
            : AppColors.green;
    return Text(priority,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
