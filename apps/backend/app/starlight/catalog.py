from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CatalogItem:
    id: str
    name: str
    constellation: str
    target_type: str  # "milky_way", "constellation", "cluster", "star"
    ra_hours: float
    dec_deg: float
    min_alt: float
    max_alt: float
    priority: int  # Higher priority preferred when altitude is suitable
    requires_dark_sky: bool
    description: str


CELESTIAL_CATALOG: list[CatalogItem] = [
    CatalogItem(
        id="perseus_milky_way",
        name="페르세우스자리 은하수",
        constellation="페르세우스자리",
        target_type="milky_way",
        ra_hours=3.4,
        dec_deg=45.0,
        min_alt=12.0,
        max_alt=80.0,
        priority=100,
        requires_dark_sky=True,
        description="가을과 겨울 밤하늘을 가로지르는 은하수의 북쪽 줄기",
    ),
    CatalogItem(
        id="cygnus_milky_way",
        name="백조자리 은하수",
        constellation="백조자리",
        target_type="milky_way",
        ra_hours=20.6,
        dec_deg=42.0,
        min_alt=15.0,
        max_alt=88.0,
        priority=95,
        requires_dark_sky=True,
        description="은하수의 가장 짙고 웅장한 북십자성 구간",
    ),
    CatalogItem(
        id="sagittarius_milky_way",
        name="궁수자리 은하수 중심부",
        constellation="궁수자리",
        target_type="milky_way",
        ra_hours=17.8,
        dec_deg=-29.0,
        min_alt=10.0,
        max_alt=35.0,
        priority=100,
        requires_dark_sky=True,
        description="우리 은하의 중심부가 밀집된 가장 밝고 거대한 은하수 영역",
    ),
    CatalogItem(
        id="cassiopeia",
        name="카시오페이아자리",
        constellation="카시오페이아자리",
        target_type="constellation",
        ra_hours=1.0,
        dec_deg=60.0,
        min_alt=15.0,
        max_alt=85.0,
        priority=80,
        requires_dark_sky=False,
        description="은하수 길목에 위치한 가을철 북쪽 밤하늘의 W자 대표 별자리",
    ),
    CatalogItem(
        id="orion",
        name="오리온자리",
        constellation="오리온자리",
        target_type="constellation",
        ra_hours=5.5,
        dec_deg=5.0,
        min_alt=15.0,
        max_alt=65.0,
        priority=90,
        requires_dark_sky=False,
        description="겨울철 밤하늘을 수놓는 가장 화려한 대표 길잡이 별자리",
    ),
    CatalogItem(
        id="pleiades",
        name="황소자리 플레이아데스 성단",
        constellation="황소자리",
        target_type="cluster",
        ra_hours=3.79,
        dec_deg=24.1,
        min_alt=15.0,
        max_alt=75.0,
        priority=85,
        requires_dark_sky=False,
        description="푸른 별들이 옹기종기 모여 맨눈으로도 반짝이는 좀생이별 산개성단",
    ),
    CatalogItem(
        id="vega_summer_triangle",
        name="거문고자리 베가(직녀성)",
        constellation="거문고자리",
        target_type="star",
        ra_hours=18.62,
        dec_deg=38.8,
        min_alt=15.0,
        max_alt=85.0,
        priority=75,
        requires_dark_sky=False,
        description="여름철 대삼각형의 꼭짓점을 이루는 푸른빛의 대표 1등성",
    ),
    CatalogItem(
        id="ursa_major",
        name="큰곰자리 북두칠성",
        constellation="큰곰자리",
        target_type="constellation",
        ra_hours=11.5,
        dec_deg=55.0,
        min_alt=15.0,
        max_alt=80.0,
        priority=80,
        requires_dark_sky=False,
        description="사계절 북쪽 하늘에서 북극성을 가리키는 국자 모양의 대표 별자리",
    ),
    CatalogItem(
        id="scorpio_antares",
        name="전갈자리 안타레스",
        constellation="전갈자리",
        target_type="star",
        ra_hours=16.48,
        dec_deg=-26.4,
        min_alt=10.0,
        max_alt=35.0,
        priority=75,
        requires_dark_sky=False,
        description="여름철 남쪽 지평선 위 붉게 타오르는 1등성 적색초거성",
    ),
]
