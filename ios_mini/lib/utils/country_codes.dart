/// 国家/地区预设列表（E.164 区号），供注册页下拉使用；展示名按当前语言取 zh 或 en
class CountryCode {
  const CountryCode({required this.code, required this.nameZh, required this.nameEn});
  final String code;   // 如 +86
  final String nameZh;
  final String nameEn;

  String displayName(bool isZh) => isZh ? nameZh : nameEn;
}

/// 常见国家/地区（规约：后端按 E.164 存储），与国际化 App 通用做法一致
const List<CountryCode> kCountryCodes = [
  CountryCode(code: '+86', nameZh: '中国', nameEn: 'China'),
  CountryCode(code: '+1', nameZh: '美国/加拿大', nameEn: 'United States / Canada'),
  CountryCode(code: '+44', nameZh: '英国', nameEn: 'United Kingdom'),
  CountryCode(code: '+81', nameZh: '日本', nameEn: 'Japan'),
  CountryCode(code: '+82', nameZh: '韩国', nameEn: 'South Korea'),
  CountryCode(code: '+852', nameZh: '中国香港', nameEn: 'Hong Kong'),
  CountryCode(code: '+853', nameZh: '中国澳门', nameEn: 'Macau'),
  CountryCode(code: '+886', nameZh: '中国台湾', nameEn: 'Taiwan'),
  CountryCode(code: '+33', nameZh: '法国', nameEn: 'France'),
  CountryCode(code: '+49', nameZh: '德国', nameEn: 'Germany'),
  CountryCode(code: '+39', nameZh: '意大利', nameEn: 'Italy'),
  CountryCode(code: '+34', nameZh: '西班牙', nameEn: 'Spain'),
  CountryCode(code: '+61', nameZh: '澳大利亚', nameEn: 'Australia'),
  CountryCode(code: '+91', nameZh: '印度', nameEn: 'India'),
  CountryCode(code: '+65', nameZh: '新加坡', nameEn: 'Singapore'),
  CountryCode(code: '+60', nameZh: '马来西亚', nameEn: 'Malaysia'),
  CountryCode(code: '+66', nameZh: '泰国', nameEn: 'Thailand'),
  CountryCode(code: '+84', nameZh: '越南', nameEn: 'Vietnam'),
  CountryCode(code: '+62', nameZh: '印度尼西亚', nameEn: 'Indonesia'),
  CountryCode(code: '+63', nameZh: '菲律宾', nameEn: 'Philippines'),
  CountryCode(code: '+55', nameZh: '巴西', nameEn: 'Brazil'),
  CountryCode(code: '+52', nameZh: '墨西哥', nameEn: 'Mexico'),
  CountryCode(code: '+7', nameZh: '俄罗斯', nameEn: 'Russia'),
  CountryCode(code: '+971', nameZh: '阿联酋', nameEn: 'United Arab Emirates'),
  CountryCode(code: '+966', nameZh: '沙特', nameEn: 'Saudi Arabia'),
  CountryCode(code: '+20', nameZh: '埃及', nameEn: 'Egypt'),
  CountryCode(code: '+27', nameZh: '南非', nameEn: 'South Africa'),
  CountryCode(code: '+234', nameZh: '尼日利亚', nameEn: 'Nigeria'),
  CountryCode(code: '+90', nameZh: '土耳其', nameEn: 'Turkey'),
  CountryCode(code: '+31', nameZh: '荷兰', nameEn: 'Netherlands'),
  CountryCode(code: '+41', nameZh: '瑞士', nameEn: 'Switzerland'),
  CountryCode(code: '+46', nameZh: '瑞典', nameEn: 'Sweden'),
  CountryCode(code: '+48', nameZh: '波兰', nameEn: 'Poland'),
  CountryCode(code: '+380', nameZh: '乌克兰', nameEn: 'Ukraine'),
  CountryCode(code: '+64', nameZh: '新西兰', nameEn: 'New Zealand'),
  CountryCode(code: '+254', nameZh: '肯尼亚', nameEn: 'Kenya'),
  CountryCode(code: '+233', nameZh: '加纳', nameEn: 'Ghana'),
  CountryCode(code: '+212', nameZh: '摩洛哥', nameEn: 'Morocco'),
  CountryCode(code: '+353', nameZh: '爱尔兰', nameEn: 'Ireland'),
  CountryCode(code: '+32', nameZh: '比利时', nameEn: 'Belgium'),
  CountryCode(code: '+43', nameZh: '奥地利', nameEn: 'Austria'),
];
