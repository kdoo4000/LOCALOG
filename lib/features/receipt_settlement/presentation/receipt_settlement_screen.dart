import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

void _previewOnly() {}

class ReceiptSettlementScreen extends StatelessWidget {
  const ReceiptSettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Text(
              '영수증 정산',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '여행에서 모은 영수증으로 경비를 간편하게 나눠요.',
              style: TextStyle(color: AppColors.gray500, height: 1.4),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(
              step: '01',
              title: '영수증 사진',
              description: '품목과 금액이 잘 보이는 사진을 올려주세요.',
            ),
            const SizedBox(height: 12),
            const _ReceiptUploadCard(),
            const SizedBox(height: 30),
            const _SectionHeader(
              step: '02',
              title: '같이 여행한 사람',
              description: '이번 결제에 함께한 사람을 선택해요.',
            ),
            const SizedBox(height: 12),
            const _TravelerCard(),
            const SizedBox(height: 30),
            const _SectionHeader(
              step: '03',
              title: '정산 품목',
              description: '품목마다 나눌 사람을 다르게 정할 수 있어요.',
            ),
            const SizedBox(height: 12),
            const _ItemCard(
              icon: Icons.ramen_dining_rounded,
              iconColor: Color(0xFFFF8A3D),
              iconBackground: Color(0xFFFFF1E8),
              name: '해물 칼국수',
              quantity: '2개',
              price: '24,000원',
              perPerson: '1인 8,000원',
              people: [
                _Person('나', Color(0xFF2457F5)),
                _Person('민지', Color(0xFFE65D8D)),
                _Person('준호', Color(0xFF00A78E)),
              ],
            ),
            const SizedBox(height: 12),
            const _ItemCard(
              icon: Icons.local_drink_rounded,
              iconColor: Color(0xFF5474E8),
              iconBackground: Color(0xFFE9EFFF),
              name: '막걸리',
              quantity: '1개',
              price: '6,000원',
              perPerson: '1인 3,000원',
              people: [
                _Person('나', Color(0xFF2457F5)),
                _Person('준호', Color(0xFF00A78E)),
              ],
            ),
            const SizedBox(height: 12),
            const _ItemCard(
              icon: Icons.icecream_rounded,
              iconColor: Color(0xFFE65D8D),
              iconBackground: Color(0xFFFFEAF2),
              name: '팥빙수',
              quantity: '1개',
              price: '12,000원',
              perPerson: '1인 12,000원',
              people: [_Person('민지', Color(0xFFE65D8D))],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _previewOnly,
              icon: const Icon(Icons.add_rounded),
              label: const Text('품목 추가'),
            ),
            const SizedBox(height: 30),
            const _SectionHeader(
              step: '04',
              title: '정산',
              description: '각자 낼 금액을 마지막으로 확인해요.',
            ),
            const SizedBox(height: 12),
            const _SettlementSummary(),
            const SizedBox(height: 18),
            const FilledButton(
              onPressed: _previewOnly,
              child: Text('정산 요청 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.step,
    required this.title,
    required this.description,
  });

  final String step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.gray500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptUploadCard extends StatelessWidget {
  const _ReceiptUploadCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 88,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gray200),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.primaryBlue,
                  size: 28,
                ),
                SizedBox(height: 7),
                Text(
                  '사진 추가',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '영수증을 촬영하거나\n앨범에서 여러 장 선택하세요',
                  style: TextStyle(fontWeight: FontWeight.w900, height: 1.35),
                ),
                SizedBox(height: 8),
                Text(
                  'JPG, PNG · 최대 10MB',
                  style: TextStyle(color: AppColors.gray500, fontSize: 12),
                ),
                SizedBox(height: 12),
                _SmallOutlineButton(
                  icon: Icons.upload_rounded,
                  label: '사진 업로드',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  const _TravelerCard();

  @override
  Widget build(BuildContext context) {
    const people = [
      _Person('나', Color(0xFF2457F5)),
      _Person('민지', Color(0xFFE65D8D)),
      _Person('준호', Color(0xFF00A78E)),
      _Person('서연', Color(0xFFFF8A3D)),
    ];

    return _Panel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final person in people) _TravelerChip(person: person),
          const _AddTravelerChip(),
        ],
      ),
    );
  }
}

class _TravelerChip extends StatelessWidget {
  const _TravelerChip({required this.person});

  final _Person person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(person: person, small: true),
          const SizedBox(width: 6),
          Text(
            person.name,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.check_rounded,
            size: 15,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

class _AddTravelerChip extends StatelessWidget {
  const _AddTravelerChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gray200),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 17,
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: 6),
          Text(
            '사용자 추가',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Person {
  const _Person(this.name, this.color);

  final String name;
  final Color color;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, this.small = false});

  final _Person person;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 26.0 : 36.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: person.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: person.color.withValues(alpha: 0.32)),
      ),
      child: Text(
        person.name.characters.first,
        style: TextStyle(
          color: person.color,
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.name,
    required this.quantity,
    required this.price,
    required this.perPerson,
    required this.people,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String name;
  final String quantity;
  final String price;
  final String perPerson;
  final List<_Person> people;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quantity,
                      style: const TextStyle(
                        color: AppColors.gray500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    perPerson,
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '나눌 사람',
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final person in people)
                      Container(
                        padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Avatar(person: person, small: true),
                            const SizedBox(width: 5),
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.gray400,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettlementSummary extends StatelessWidget {
  const _SettlementSummary();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (_Person('나', Color(0xFF2457F5)), '11,000원'),
      (_Person('민지', Color(0xFFE65D8D)), '20,000원'),
      (_Person('준호', Color(0xFF00A78E)), '11,000원'),
    ];

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Text(
                  '총 결제 금액',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '42,000원',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  _Avatar(person: row.$1, small: true),
                  const SizedBox(width: 9),
                  Text(
                    row.$1.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    row.$2,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray200),
      ),
      child: child,
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  const _SmallOutlineButton({
    required this.icon,
    required this.label,
    this.fillWidth = false,
  });

  final IconData icon;
  final String label;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return fillWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
