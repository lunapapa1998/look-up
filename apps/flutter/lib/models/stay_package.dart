/// Figma content examples, not saleable inventory or real-time travel data.
enum PackageCategory {
  forest('산림·습지형'),
  coastal('도서·갯벌형');

  const PackageCategory(this.label);
  final String label;
}

enum PackageMoment { day, sunset, night }

class PackageStop {
  const PackageStop(this.time, this.title, this.description, this.moment);
  final String time;
  final String title;
  final String description;
  final PackageMoment moment;
}

class StayPackage {
  const StayPackage({
    required this.id,
    required this.title,
    required this.eyebrow,
    required this.category,
    required this.imageAsset,
    required this.badges,
    required this.benefits,
    required this.stops,
    required this.transport,
    required this.pricePerPerson,
  });
  final String id;
  final String title;
  final String eyebrow;
  final PackageCategory category;
  final String imageAsset;
  final List<String> badges;
  final List<String> benefits;
  final List<PackageStop> stops;
  final String transport;
  final int pricePerPerson;
}

String formatPackagePrice(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

const exampleStayPackages = [
  StayPackage(
    id: 'inje',
    category: PackageCategory.forest,
    title: '강원 인제 — 비무장지대 두루미 & 곰배령 다크스카이',
    eyebrow: 'GANGWON INJE DMZ · 1 NIGHT 2 DAYS',
    imageAsset: 'assets/packages/inje.jpg',
    badges: ['생태관광 인증', '다크스카이 테마'],
    benefits: ['입문용 관찰키트 무상대여', '로컬 노포 식음 바우처 20,000원', 'KTX 진부역 전기 셔틀 왕복'],
    transport: 'KTX + 연계 전기셔틀 포함',
    pricePerPerson: 128000,
    stops: [
      PackageStop(
        '14:00 DAY 1',
        '두루미·재두루미 군무 탐조',
        '인제 평화생태 습지 갈대밭에서 전문 생태해설사와 동행하는 탐조 일정.',
        PackageMoment.day,
      ),
      PackageStop(
        '18:00 SUNSET',
        '인제 황태구이 로컬 미식',
        '자연 건조한 황태구이 정식으로 쉬어가는 석식과 연계 셔틀 일정.',
        PackageMoment.sunset,
      ),
      PackageStop(
        '21:30 NIGHT',
        '곰배령 밤하늘 천체관측',
        '카시오페이아와 겨울철 대삼각형을 찾아보는 관측 일정. 실제 운영 장소와 접근 가능 여부는 확정 전입니다.',
        PackageMoment.night,
      ),
      PackageStop(
        '08:30 DAY 2',
        '아침 숲새 소리 & 자작나무 숲길',
        '동고비와 쇠딱따구리 울음소리를 듣고 걷는 4km 숲길 트레킹 일정.',
        PackageMoment.day,
      ),
    ],
  ),
  StayPackage(
    id: 'heuksando',
    category: PackageCategory.coastal,
    title: '전남 신안 흑산도 — 갯벌 도요새 & 섬 밤하늘 은하수',
    eyebrow: 'SHIN-AN HEUKSANDO · 1 NIGHT 2 DAYS',
    imageAsset: 'assets/packages/heuksando.jpg',
    badges: ['갯벌 생태여행 테마', '다크스카이 테마'],
    benefits: ['조석 만조 타이밍 연계 탐조선', '흑산도 로컬 미식 바우처 25,000원', '고성능 굴절망원경 세션'],
    transport: '쾌속선 왕복 + 섬내 이동 포함',
    pricePerPerson: 145000,
    stops: [
      PackageStop(
        '13:30 DAY 1',
        '만조 갯벌 도요물떼새 관찰',
        '밀물에 맞춰 모여드는 도요물떼새를 목재 관찰데크에서 만나는 탐조 일정.',
        PackageMoment.day,
      ),
      PackageStop(
        '18:30 EVENING',
        '흑산도 숙성 홍어 & 제철 해산물',
        '로컬 해초밥과 삼합을 함께 맛보는 섬 미식 일정.',
        PackageMoment.sunset,
      ),
      PackageStop(
        '22:00 NIGHT',
        '청정 해안 데크 밤하늘 관측',
        '해안 데크에서 성단과 은하수를 찾아보는 일정. 현장 기상과 관측 가능 여부는 별도 확인이 필요합니다.',
        PackageMoment.night,
      ),
    ],
  ),
];
