-- Auto-generated segmenter code
-- Generated from: mozc/src/data/rules/segmenter.def
local segmenter = {}

-- Constants
segmenter.L_SIZE = 2673
segmenter.R_SIZE = 2673

-- Boundary checking function
-- @param rid: Right node POS ID (uint16_t)
-- @param lid: Left node POS ID (uint16_t)  
-- @return: boolean - true if boundary exists, false otherwise
function segmenter.is_boundary_internal(rid, lid)
  -- BOS * or * EOS always has boundary
  if rid == 0 or lid == 0 then
    return true
  end

  -- 名詞,数,アラビア数字 名詞,数,(アラビア数字|漢数字) false
  if ((rid == 2042)) and ((lid == 2042) or (lid >= 2044 and lid <= 2053)) then return false end
  -- 名詞,数,漢数字 名詞,数,アラビア数字 true
  if ((rid >= 2044 and rid <= 2053)) and ((lid == 2042)) then return true end
  -- 名詞,数,漢数字 名詞,数,漢数字 false
  if ((rid >= 2044 and rid <= 2053)) and ((lid >= 2044 and lid <= 2053)) then return false end
  -- 名詞,数,(アラビア数字|漢数字) 名詞,数,区切り文字 false
  if ((rid == 2042) or (rid >= 2044 and rid <= 2053)) and ((lid == 2043)) then return false end
  -- 名詞,数,区切り文字 名詞,数,(アラビア数字|漢数字) false
  if ((rid == 2043)) and ((lid == 2042) or (lid >= 2044 and lid <= 2053)) then return false end
  -- 接頭詞,数接続 名詞,数,漢数字 false
  if ((rid >= 2637 and rid <= 2640)) and ((lid >= 2044 and lid <= 2053)) then return false end
  -- 接頭詞,数接続 名詞,接尾,助数詞 false
  if ((rid >= 2637 and rid <= 2640)) and ((lid >= 2009 and lid <= 2016)) then return false end
  -- 接頭詞,数接続 名詞,(一般|サ変接続|形容動詞語幹|副詞可能) true
  if ((rid >= 2637 and rid <= 2640)) and ((lid >= 1841 and lid <= 1849) or (lid >= 1851 and lid <= 1898) or (lid >= 1909 and lid <= 1918) or (lid >= 1931 and lid <= 1935)) then return true end
  -- 記号,(句点|読点|括弧開|括弧閉) * true
  if ((rid >= 2643 and rid <= 2656)) and (true) then return true end
  -- * 記号,(句点|読点|括弧開|括弧閉|空白) true
  if (true) and ((lid >= 2643 and lid <= 2656)) then return true end
  -- ^フィラー * true
  if ((rid >= 2 and rid <= 11)) and (true) then return true end
  -- * ^フィラー true
  if (true) and ((lid >= 2 and lid <= 11)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(あげる|上げる|つづける|続ける|そこねる|そびれる|おえる|終える|はじめる|始める|ねがえる|願える|もらえる) true
  if (true) and ((lid == 877) or (lid >= 886 and lid <= 887) or (lid == 890) or (lid == 896) or (lid == 899) or (lid == 901) or (lid == 905) or (lid >= 914 and lid <= 915) or (lid >= 917 and lid <= 918) or (lid >= 927 and lid <= 928) or (lid == 931) or (lid == 937) or (lid == 940) or (lid == 942) or (lid == 946) or (lid >= 955 and lid <= 956) or (lid >= 958 and lid <= 959) or (lid >= 968 and lid <= 969) or (lid == 972) or (lid == 978) or (lid == 981) or (lid == 983) or (lid == 987) or (lid >= 996 and lid <= 997) or (lid >= 999 and lid <= 1000) or (lid >= 1009 and lid <= 1010) or (lid == 1013) or (lid == 1019) or (lid == 1022) or (lid == 1024) or (lid == 1028) or (lid >= 1037 and lid <= 1038) or (lid >= 1040 and lid <= 1041) or (lid >= 1050 and lid <= 1051) or (lid == 1054) or (lid == 1060) or (lid == 1063) or (lid == 1065) or (lid == 1069) or (lid >= 1078 and lid <= 1079) or (lid >= 1081 and lid <= 1082) or (lid >= 1091 and lid <= 1092) or (lid == 1095) or (lid == 1101) or (lid == 1104) or (lid == 1106) or (lid == 1110) or (lid >= 1119 and lid <= 1120) or (lid >= 1122 and lid <= 1123) or (lid >= 1132 and lid <= 1133) or (lid == 1136) or (lid == 1142) or (lid == 1145) or (lid == 1147) or (lid == 1151) or (lid >= 1160 and lid <= 1161) or (lid >= 1163 and lid <= 1164) or (lid >= 1173 and lid <= 1174) or (lid == 1177) or (lid == 1183) or (lid >= 1186 and lid <= 1187) or (lid == 1191) or (lid >= 1200 and lid <= 1201) or (lid >= 1203 and lid <= 1204) or (lid >= 1213 and lid <= 1214) or (lid == 1217) or (lid == 1223) or (lid >= 1226 and lid <= 1227) or (lid == 1231) or (lid >= 1240 and lid <= 1241) or (lid == 1243)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(いただく|頂く|ぬく|抜く) true
  if (true) and ((lid == 1258) or (lid == 1262) or (lid == 1265) or (lid >= 1269 and lid <= 1270) or (lid == 1274) or (lid == 1277) or (lid >= 1281 and lid <= 1282) or (lid == 1286) or (lid == 1289) or (lid >= 1293 and lid <= 1294) or (lid == 1298) or (lid == 1301) or (lid >= 1305 and lid <= 1306) or (lid == 1310) or (lid == 1313) or (lid >= 1317 and lid <= 1318) or (lid == 1322) or (lid == 1325) or (lid >= 1329 and lid <= 1330) or (lid == 1334) or (lid == 1337) or (lid >= 1341 and lid <= 1342) or (lid == 1346) or (lid == 1349) or (lid == 1353)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(いたす|致す|つくす|尽くす|なおす|直す) true
  if (true) and ((lid == 1409) or (lid >= 1411 and lid <= 1412) or (lid >= 1414 and lid <= 1417) or (lid >= 1419 and lid <= 1420) or (lid >= 1422 and lid <= 1425) or (lid >= 1427 and lid <= 1428) or (lid >= 1430 and lid <= 1433) or (lid >= 1435 and lid <= 1436) or (lid >= 1438 and lid <= 1441) or (lid >= 1443 and lid <= 1444) or (lid >= 1446 and lid <= 1449) or (lid >= 1451 and lid <= 1452) or (lid >= 1454 and lid <= 1457) or (lid >= 1459 and lid <= 1460) or (lid >= 1462 and lid <= 1464)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(こむ|込む) true
  if (true) and ((lid >= 1465 and lid <= 1480)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(おわる|終わる|いらっしゃる|らっしゃる|下さる|くださる|クダサル) true
  if (true) and ((lid == 1500) or (lid == 1521) or (lid == 1541) or (lid == 1558) or (lid == 1578) or (lid == 1598) or (lid == 1618) or (lid == 1638) or (lid == 1658) or (lid == 1678) or (lid >= 1699 and lid <= 1701) or (lid >= 1703 and lid <= 1706) or (lid >= 1708 and lid <= 1711) or (lid >= 1713 and lid <= 1716) or (lid >= 1721 and lid <= 1722) or (lid >= 1724 and lid <= 1726) or (lid >= 1728 and lid <= 1731) or (lid >= 1733 and lid <= 1736) or (lid >= 1738 and lid <= 1741) or (lid >= 1743 and lid <= 1746) or (lid >= 1748 and lid <= 1751) or (lid == 1753) or (lid == 1755)) then return true end
  -- * ^動詞,非自立,*,*,*,*,(あう|合う|願う|もらう) true
  if (true) and ((lid == 1758) or (lid >= 1765 and lid <= 1766) or (lid >= 1768 and lid <= 1769) or (lid >= 1775 and lid <= 1776) or (lid >= 1778 and lid <= 1779) or (lid == 1786) or (lid == 1788) or (lid >= 1790 and lid <= 1791) or (lid >= 1798 and lid <= 1799) or (lid >= 1801 and lid <= 1802) or (lid >= 1809 and lid <= 1810) or (lid >= 1812 and lid <= 1813) or (lid == 1820) or (lid == 1822) or (lid >= 1824 and lid <= 1825) or (lid >= 1832 and lid <= 1833) or (lid == 1835)) then return true end
  -- 接頭詞,動詞接続 動詞 false
  if ((rid >= 2594 and rid <= 2597)) and ((lid >= 434 and lid <= 1840)) then return false end
  -- * ^名詞,接尾可能 true
  if (true) and ((lid >= 2038 and lid <= 2039)) then return true end
  -- ^助詞,接続助詞 ^動詞,非自立 false
  if ((rid >= 329 and rid <= 367)) and ((lid >= 857 and lid <= 1840)) then return false end
  -- ^動詞,自立 ^動詞,非自立 false
  if ((rid >= 577 and rid <= 856)) and ((lid >= 857 and lid <= 1840)) then return false end
  -- 副詞,一般,*,*,*,*,よく 動詞,自立,*,*,五段・ラ行,*,なる false
  if ((rid == 14)) and ((lid == 745) or (lid == 749) or (lid == 753) or (lid == 757) or (lid == 761) or (lid == 765) or (lid == 769) or (lid == 773) or (lid == 777) or (lid == 781) or (lid == 785)) then return false end
  -- 名詞,接尾,サ変接続 動詞,自立,*,*,サ変・スル false
  if ((rid >= 1936 and rid <= 1948)) and ((lid >= 627 and lid <= 638)) then return false end
  -- * 動詞,非自立,*,*,五段・カ行促音便,連用タ接続,く false
  if (true) and ((lid == 1386)) then return false end
  -- ^接頭詞 ^接頭詞 true
  if ((rid >= 2594 and rid <= 2640)) and ((lid >= 2594 and lid <= 2640)) then return true end
  -- * 名詞,非自立,形容動詞語幹,*,*,*,みたい false
  if (true) and ((lid == 2193)) then return false end
  -- * ^助詞,*,*,*,*,*,(ヲ|ニ|ナ|ネ|ヨ|ン|ヨー|ワ|デ|ノ|ヘ|ヲ|之|ナア|ネェ|ヨー|なァ)$ true
  if (true) and ((lid >= 381 and lid <= 385)) then return true end
  -- * 名詞,非自立,副詞可能,*,*,*,(きり|ため|っきり|はず|ほど|まま) false
  if (true) and ((lid == 2133) or (lid >= 2138 and lid <= 2139) or (lid >= 2149 and lid <= 2151)) then return false end
  -- * 名詞,非自立,副詞可能 true
  if (true) and ((lid >= 2128 and lid <= 2187)) then return true end
  -- * 名詞,非自立,一般,*,*,*,(コト|フシ|ホ|モノ|ン) true
  if (true) and ((lid == 2093) or (lid >= 2096 and lid <= 2099)) then return true end
  -- * 助動詞,*,*,*,特殊・デス,基本形,ッス true
  if (true) and ((lid == 177)) then return true end
  -- * 助動詞,*,*,*,特殊・デス,基本形,デス true
  if (true) and ((lid == 178)) then return true end
  -- * 助動詞,*,*,*,特殊・デス,基本形,ドス true
  if (true) and ((lid == 179)) then return true end
  -- * 助動詞,*,*,*,特殊・デス,未然形,ッス true
  if (true) and ((lid == 188)) then return true end
  -- * 助動詞,*,*,*,不変化型,基本形,じゃン true
  if (true) and ((lid == 38)) then return true end
  -- * 名詞,固有名詞,地域,一般 true
  if (true) and ((lid >= 1924 and lid <= 1927)) then return true end
  -- 接頭詞,名詞接続 * false
  if ((rid >= 2598 and rid <= 2635)) and (true) then return false end
  -- 連体詞, ^名詞 true
  if ((rid >= 2657 and rid <= 2669)) and ((lid >= 1841 and lid <= 2193)) then return true end
  -- * 助動詞,*,*,*,形容詞・イ段,*,無い true
  if (true) and ((lid == 71) or (lid == 73) or (lid == 75) or (lid == 77) or (lid == 79) or (lid == 81) or (lid == 83) or (lid == 85) or (lid == 87) or (lid == 89) or (lid == 91) or (lid == 93) or (lid == 95)) then return true end
  -- 動詞 助動詞,*,*,*,形容詞・イ段,*,無い true
  if ((rid >= 434 and rid <= 1840)) and ((lid == 71) or (lid == 73) or (lid == 75) or (lid == 77) or (lid == 79) or (lid == 81) or (lid == 83) or (lid == 85) or (lid == 87) or (lid == 89) or (lid == 91) or (lid == 93) or (lid == 95)) then return true end
  -- ^(助動詞|動詞),*,*,*,*,基本形 名詞,非自立,一般,*,*,*,(事|コト) true
  if ((rid == 32) or (rid >= 35 and rid <= 48) or (rid == 53) or (rid >= 62 and rid <= 63) or (rid >= 82 and rid <= 83) or (rid == 98) or (rid == 100) or (rid >= 103 and rid <= 104) or (rid >= 114 and rid <= 115) or (rid >= 120 and rid <= 121) or (rid == 126) or (rid == 129) or (rid == 134) or (rid == 137) or (rid >= 142 and rid <= 143) or (rid >= 151 and rid <= 154) or (rid == 165) or (rid >= 169 and rid <= 179) or (rid >= 203 and rid <= 206) or (rid == 217) or (rid >= 239 and rid <= 244) or (rid == 265) or (rid >= 464 and rid <= 469) or (rid >= 512 and rid <= 519) or (rid >= 558 and rid <= 560) or (rid >= 590 and rid <= 591) or (rid >= 609 and rid <= 610) or (rid == 621) or (rid == 633) or (rid == 642) or (rid >= 680 and rid <= 686) or (rid == 713) or (rid == 719) or (rid == 723) or (rid == 731) or (rid == 739) or (rid >= 763 and rid <= 766) or (rid == 791) or (rid == 799) or (rid >= 813 and rid <= 816) or (rid == 837) or (rid == 845) or (rid == 852) or (rid == 863) or (rid == 873) or (rid >= 1082 and rid <= 1122) or (rid == 1249) or (rid >= 1256 and rid <= 1257) or (rid >= 1294 and rid <= 1305) or (rid >= 1370 and rid <= 1374) or (rid >= 1401 and rid <= 1402) or (rid >= 1433 and rid <= 1440) or (rid >= 1471 and rid <= 1472) or (rid >= 1579 and rid <= 1598) or (rid >= 1725 and rid <= 1729) or (rid >= 1779 and rid <= 1790) or (rid == 1838)) and ((lid == 2093) or (lid == 2101)) then return true end
  -- ^名詞 助動詞,*,*,*,(文語・ル|文語・リ|文語・マジ|文語・ゴトシ|文語・ケリ|文語・キ) true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 96 and lid <= 106) or (lid >= 124 and lid <= 136)) then return true end
  -- ^助詞 名詞,非自立,副詞可能,*,*,*,以内 true
  if ((rid >= 268 and rid <= 433)) and ((lid == 2160)) then return true end
  -- ^(動詞|助動詞|形容詞) 名詞,非自立,副詞可能,*,*,*,他 true
  if ((rid >= 29 and rid <= 267) or (rid >= 434 and rid <= 1840) or (rid >= 2194 and rid <= 2588)) and ((lid == 2158)) then return true end
  -- ^名詞,サ変接続 動詞,自立,*,*,一段,*,できる false
  if ((rid >= 1841 and rid <= 1849)) and ((lid == 648) or (lid == 655) or (lid == 662) or (lid == 669) or (lid == 676) or (lid == 683) or (lid == 690) or (lid == 697) or (lid == 704)) then return false end
  -- * 名詞,非自立,助動詞語幹,*,*,*,よう false
  if (true) and ((lid == 2190)) then return false end
  -- * 名詞,非自立,助動詞語幹,*,*,*,様 true
  if (true) and ((lid == 2191)) then return true end
  -- ^名詞,非自立 ^助詞 false
  if ((rid >= 2055 and rid <= 2193)) and ((lid >= 268 and lid <= 433)) then return false end
  -- ^名詞 助詞,終助詞,*,*,*,*,(よ|ね|の) false
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 423 and lid <= 424) or (lid == 430)) then return false end
  -- ^名詞 ^助詞,(終助詞|特殊|接続助詞|動詞非自立的) true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 329 and lid <= 367) or (lid >= 399 and lid <= 432)) then return true end
  -- ^名詞 ^名詞,非自立,(一般|助動詞語幹|形容動詞語幹) true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 2055 and lid <= 2127) or (lid >= 2188 and lid <= 2193)) then return true end
  -- ^名詞 ^形容詞,非自立 true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 2471 and lid <= 2588)) then return true end
  -- ^名詞 ^動詞,(接尾|非自立) true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 434 and lid <= 576) or (lid >= 857 and lid <= 1840)) then return true end
  -- ^(動詞|形容詞|助動詞) 名詞,接尾,(サ変接続|人名|副詞可能|助数詞|地域|形容動詞語幹|形容動詞語幹) true
  if ((rid >= 29 and rid <= 267) or (rid >= 434 and rid <= 1840) or (rid >= 2194 and rid <= 2588)) and ((lid >= 1936 and lid <= 1948) or (lid >= 1998 and lid <= 2006) or (lid >= 2009 and lid <= 2030)) then return true end
  -- ^(動詞|形容詞|助動詞) 形容詞,非自立,*,*,形容詞・アウオ段,*,良い true
  if ((rid >= 29 and rid <= 267) or (rid >= 434 and rid <= 1840) or (rid >= 2194 and rid <= 2588)) and ((lid == 2480) or (lid == 2487) or (lid == 2494) or (lid == 2501) or (lid == 2508) or (lid == 2520) or (lid == 2528) or (lid == 2535) or (lid == 2542) or (lid == 2549) or (lid == 2556) or (lid == 2563)) then return true end
  -- ^助動詞,*,*,*,特殊・タ,基本形,た ^助詞,終助詞,*,*,*,*,かな true
  if ((rid == 142)) and ((lid == 412)) then return true end
  -- ^接頭詞,名詞接続 ^(動詞|形容詞) true
  if ((rid >= 2598 and rid <= 2635)) and ((lid >= 434 and lid <= 1840) or (lid >= 2194 and lid <= 2588)) then return true end
  -- 名詞,固有名詞,人名 名詞,接尾,人名 false
  if ((rid >= 1921 and rid <= 1923)) and ((lid == 1998)) then return false end
  -- 名詞,固有名詞,一般 名詞,接尾,人名 false
  if ((rid == 1920)) and ((lid == 1998)) then return false end
  -- 名詞,固有名詞,地域 名詞,接尾,地域 false
  if ((rid >= 1924 and rid <= 1928)) and ((lid >= 2017 and lid <= 2025)) then return false end
  -- 名詞,数 名詞,接尾,助数詞 true
  if ((rid >= 2041 and rid <= 2053)) and ((lid >= 2009 and lid <= 2016)) then return true end
  -- 名詞,接尾,特殊 名詞,接尾,助動詞語幹 false
  if ((rid >= 2031 and rid <= 2037)) and ((lid >= 2007 and lid <= 2008)) then return false end
  -- 名詞 名詞,接尾,副詞可能 true
  if ((rid >= 1841 and rid <= 2193)) and ((lid >= 1999 and lid <= 2006)) then return true end
  -- 名詞,接尾,助数詞 名詞,接尾 false
  if ((rid >= 2009 and rid <= 2016)) and ((lid >= 1936 and lid <= 2039)) then return false end
  -- ^名詞,接尾 ^名詞,接尾 true
  if ((rid >= 1936 and rid <= 2039)) and ((lid >= 1936 and lid <= 2039)) then return true end
  -- * ^名詞,接尾,(副詞可能|助動詞語幹|特殊) false
  if (true) and ((lid >= 1999 and lid <= 2008) or (lid >= 2031 and lid <= 2037)) then return false end
  -- * ^名詞,接尾 true
  if (true) and ((lid >= 1936 and lid <= 2039)) then return true end
  -- ^助動詞,*,*,*,特殊・ダ ^名詞,非自立 false
  if ((rid >= 162 and rid <= 168)) and ((lid >= 2055 and lid <= 2193)) then return false end
  -- ^動詞 動詞,非自立,*,*,五段・ワ行促音便,*,(ちまう|ちゃう|じまう|じゃう) false
  if ((rid >= 434 and rid <= 1840)) and ((lid >= 1760 and lid <= 1761) or (lid >= 1763 and lid <= 1764) or (lid >= 1771 and lid <= 1774) or (lid >= 1781 and lid <= 1782) or (lid >= 1784 and lid <= 1785) or (lid >= 1793 and lid <= 1794) or (lid >= 1796 and lid <= 1797) or (lid >= 1804 and lid <= 1805) or (lid >= 1807 and lid <= 1808) or (lid >= 1815 and lid <= 1816) or (lid >= 1818 and lid <= 1819) or (lid >= 1827 and lid <= 1828) or (lid >= 1830 and lid <= 1831)) then return false end
  -- ^動詞 動詞,非自立,*,*,五段・カ行促音便,*,(てく|どく) false
  if ((rid >= 434 and rid <= 1840)) and ((lid == 1356) or (lid == 1361) or (lid == 1367) or (lid == 1372) or (lid == 1377) or (lid == 1382) or (lid == 1387) or (lid == 1392)) then return false end
  -- ^動詞 動詞,非自立,*,*,五段・カ行イ音便,*,とく false
  if ((rid >= 434 and rid <= 1840)) and ((lid == 1260) or (lid == 1272) or (lid == 1284) or (lid == 1296) or (lid == 1308) or (lid == 1320) or (lid == 1332) or (lid == 1344)) then return false end
  -- ^動詞 動詞,非自立,*,*,一段,*,(てる|でる) false
  if ((rid >= 434 and rid <= 1840)) and ((lid == 892) or (lid == 894) or (lid == 933) or (lid == 935) or (lid == 974) or (lid == 976) or (lid == 1015) or (lid == 1017) or (lid == 1056) or (lid == 1058) or (lid == 1097) or (lid == 1099) or (lid == 1138) or (lid == 1140) or (lid == 1179) or (lid == 1181) or (lid == 1219) or (lid == 1221)) then return false end
  -- ^動詞 動詞,非自立,*,*,五段・ラ行,*,(とる|どる) false
  if ((rid >= 434 and rid <= 1840)) and ((lid >= 1487 and lid <= 1488) or (lid >= 1507 and lid <= 1508) or (lid >= 1528 and lid <= 1529) or (lid >= 1547 and lid <= 1548) or (lid >= 1565 and lid <= 1566) or (lid >= 1585 and lid <= 1586) or (lid >= 1605 and lid <= 1606) or (lid >= 1625 and lid <= 1626) or (lid >= 1645 and lid <= 1646) or (lid >= 1665 and lid <= 1666) or (lid >= 1685 and lid <= 1686)) then return false end
  -- ^副詞,助詞類接続,*,*,*,*,(そう|こう|どう|どぉ) ^動詞,自立,*,*,五段・ラ行,*,なる false
  if ((rid == 17) or (rid >= 21 and rid <= 23)) and ((lid == 745) or (lid == 749) or (lid == 753) or (lid == 757) or (lid == 761) or (lid == 765) or (lid == 769) or (lid == 773) or (lid == 777) or (lid == 781) or (lid == 785)) then return false end
  -- ^形容詞,自立,*,*,*,連用テ接続 ^動詞,自立,*,*,五段・ラ行,*,なる false
  if ((rid >= 2452 and rid <= 2456) or (rid == 2470)) and ((lid == 745) or (lid == 749) or (lid == 753) or (lid == 757) or (lid == 761) or (lid == 765) or (lid == 769) or (lid == 773) or (lid == 777) or (lid == 781) or (lid == 785)) then return false end
  -- ^名詞,副詞可能 ^動詞,自立,*,*,五段・ラ行,*,なる false
  if ((rid >= 1909 and rid <= 1918)) and ((lid == 745) or (lid == 749) or (lid == 753) or (lid == 757) or (lid == 761) or (lid == 765) or (lid == 769) or (lid == 773) or (lid == 777) or (lid == 781) or (lid == 785)) then return false end
  -- ^助詞,*,*,*,*,*,(は|に|で|も|が|の) ^動詞,自立,*,*,五段・ラ行,*,ある true
  if ((rid >= 283 and rid <= 284) or (rid == 299) or (rid == 308) or (rid >= 327 and rid <= 328) or (rid >= 332 and rid <= 333) or (rid == 349) or (rid >= 357 and rid <= 360) or (rid == 362) or (rid == 367) or (rid >= 369 and rid <= 370) or (rid >= 372 and rid <= 374) or (rid == 376) or (rid >= 397 and rid <= 398) or (rid >= 401 and rid <= 402) or (rid == 420) or (rid == 424) or (rid == 426) or (rid == 433)) and ((lid == 743) or (lid == 747) or (lid == 751) or (lid == 755) or (lid == 759) or (lid == 763) or (lid == 767) or (lid == 771) or (lid == 775) or (lid == 779) or (lid == 783)) then return true end
  -- ^助詞,*,*,*,*,*,(は|に|で|も|が|の|と) ^動詞,自立,*,*,サ変・スル,* false
  if ((rid >= 271 and rid <= 272) or (rid >= 283 and rid <= 284) or (rid >= 299 and rid <= 300) or (rid == 308) or (rid >= 326 and rid <= 328) or (rid >= 332 and rid <= 333) or (rid >= 349 and rid <= 351) or (rid >= 357 and rid <= 360) or (rid == 362) or (rid == 367) or (rid >= 369 and rid <= 374) or (rid == 376) or (rid == 387) or (rid == 389) or (rid >= 395 and rid <= 398) or (rid >= 401 and rid <= 402) or (rid == 420) or (rid == 424) or (rid == 426) or (rid == 433)) and ((lid >= 627 and lid <= 638)) then return false end
  -- ^名詞,(一般|サ変接続|形容動詞語幹|副詞可能) ^動詞,自立,*,*,サ変・スル,* false
  if ((rid >= 1841 and rid <= 1849) or (rid >= 1851 and rid <= 1898) or (rid >= 1909 and rid <= 1918) or (rid >= 1931 and rid <= 1935)) and ((lid >= 627 and lid <= 638)) then return false end
  -- ^(形容詞|動詞|副詞) ^動詞,自立,*,*,サ変・スル,* false
  if ((rid >= 12 and rid <= 28) or (rid >= 434 and rid <= 1840) or (rid >= 2194 and rid <= 2588)) and ((lid >= 627 and lid <= 638)) then return false end
  -- * ^動詞,自立,*,*,サ変・スル,* true
  if (true) and ((lid >= 627 and lid <= 638)) then return true end
  -- ^助詞,*,*,*,*,*,(は|に|で|も|が|の) 形容詞,自立,*,*,形容詞・アウオ段,*,ない false
  if ((rid >= 283 and rid <= 284) or (rid == 299) or (rid == 308) or (rid >= 327 and rid <= 328) or (rid >= 332 and rid <= 333) or (rid == 349) or (rid >= 357 and rid <= 360) or (rid == 362) or (rid == 367) or (rid >= 369 and rid <= 370) or (rid >= 372 and rid <= 374) or (rid == 376) or (rid >= 397 and rid <= 398) or (rid >= 401 and rid <= 402) or (rid == 420) or (rid == 424) or (rid == 426) or (rid == 433)) and ((lid == 2392) or (lid == 2397) or (lid == 2402) or (lid == 2407) or (lid == 2412) or (lid == 2419) or (lid == 2424) or (lid == 2428) or (lid == 2433) or (lid == 2438) or (lid == 2443) or (lid == 2448) or (lid == 2453)) then return false end
  -- * 名詞,非自立,形容動詞語幹,*,*,*,ふう true
  if (true) and ((lid == 2192)) then return true end
  -- ^副詞,一般 形容詞,(接尾|非自立) true
  if ((rid >= 12 and rid <= 15)) and ((lid >= 2194 and lid <= 2388) or (lid >= 2471 and lid <= 2588)) then return true end
  -- ^助詞 形容詞,(接尾|非自立) true
  if ((rid >= 268 and rid <= 433)) and ((lid >= 2194 and lid <= 2388) or (lid >= 2471 and lid <= 2588)) then return true end
  -- 助動詞,*,*,*,特殊・ダ 名詞 true
  if ((rid >= 162 and rid <= 168)) and ((lid >= 1841 and lid <= 2193)) then return true end
  -- * ^(その他|フィラー|感動詞) true
  if (true) and ((lid >= 1 and lid <= 11) or (lid >= 2589 and lid <= 2590)) then return true end
  -- * ^記号,(括弧開|括弧閉|アルファベット|一般) true
  if (true) and ((lid >= 2641 and lid <= 2642) or (lid >= 2653 and lid <= 2654)) then return true end
  -- * ^記号,(句点|読点) true
  if (true) and ((lid >= 2643 and lid <= 2652) or (lid >= 2655 and lid <= 2656)) then return true end
  -- * ^形容詞,自立 true
  if (true) and ((lid >= 2389 and lid <= 2470)) then return true end
  -- * ^形容詞,(接尾|非自立) false
  if (true) and ((lid >= 2194 and lid <= 2388) or (lid >= 2471 and lid <= 2588)) then return false end
  -- * ^(助詞|助動詞) false
  if (true) and ((lid >= 29 and lid <= 433)) then return false end
  -- * ^動詞,自立 true
  if (true) and ((lid >= 577 and lid <= 856)) then return true end
  -- * ^動詞,接尾 false
  if (true) and ((lid >= 434 and lid <= 576)) then return false end
  -- * ^名詞,(接続詞的|接尾|動詞非自立的|特殊|非自立) false
  if (true) and ((lid == 1919) or (lid >= 1936 and lid <= 2040) or (lid >= 2054 and lid <= 2193)) then return false end
  -- * ^名詞 true
  if (true) and ((lid >= 1841 and lid <= 2193)) then return true end
  -- * ^助詞,接続助詞,*,*,*,*,て false
  if (true) and ((lid == 348)) then return false end
  -- * 動詞,非自立,*,*,*,*,(いける|いる|える|かける|かねる|きれる|すぎる|たげる|つづける|づける|づける|できる|どける|のける|みせる|みる|もらえる|る|く|尽くす) false
  if (true) and ((lid >= 857 and lid <= 866) or (lid >= 878 and lid <= 880) or (lid >= 882 and lid <= 885) or (lid == 888) or (lid >= 890 and lid <= 891) or (lid == 893) or (lid == 895) or (lid >= 897 and lid <= 900) or (lid >= 919 and lid <= 921) or (lid >= 923 and lid <= 926) or (lid == 929) or (lid >= 931 and lid <= 932) or (lid == 934) or (lid == 936) or (lid >= 938 and lid <= 941) or (lid >= 960 and lid <= 962) or (lid >= 964 and lid <= 967) or (lid == 970) or (lid >= 972 and lid <= 973) or (lid == 975) or (lid == 977) or (lid >= 979 and lid <= 982) or (lid >= 1001 and lid <= 1003) or (lid >= 1005 and lid <= 1008) or (lid == 1011) or (lid >= 1013 and lid <= 1014) or (lid == 1016) or (lid == 1018) or (lid >= 1020 and lid <= 1023) or (lid >= 1042 and lid <= 1044) or (lid >= 1046 and lid <= 1049) or (lid == 1052) or (lid >= 1054 and lid <= 1055) or (lid == 1057) or (lid == 1059) or (lid >= 1061 and lid <= 1064) or (lid >= 1083 and lid <= 1085) or (lid >= 1087 and lid <= 1090) or (lid == 1093) or (lid >= 1095 and lid <= 1096) or (lid == 1098) or (lid == 1100) or (lid >= 1102 and lid <= 1105) or (lid >= 1124 and lid <= 1126) or (lid >= 1128 and lid <= 1131) or (lid == 1134) or (lid >= 1136 and lid <= 1137) or (lid == 1139) or (lid == 1141) or (lid >= 1143 and lid <= 1146) or (lid >= 1165 and lid <= 1167) or (lid >= 1169 and lid <= 1172) or (lid == 1175) or (lid >= 1177 and lid <= 1178) or (lid == 1180) or (lid == 1182) or (lid >= 1184 and lid <= 1186) or (lid >= 1205 and lid <= 1207) or (lid >= 1209 and lid <= 1212) or (lid == 1215) or (lid >= 1217 and lid <= 1218) or (lid == 1220) or (lid == 1222) or (lid >= 1224 and lid <= 1226) or (lid >= 1244 and lid <= 1253) or (lid == 1355) or (lid == 1360) or (lid == 1366) or (lid == 1371) or (lid == 1376) or (lid == 1381) or (lid == 1386) or (lid == 1391) or (lid == 1414) or (lid == 1422) or (lid == 1430) or (lid == 1438) or (lid == 1446) or (lid == 1454) or (lid == 1462) or (lid == 1701) or (lid == 1706) or (lid == 1711) or (lid == 1716) or (lid == 1726) or (lid == 1731) or (lid == 1736) or (lid == 1741) or (lid == 1746) or (lid == 1751)) then return false end
  -- * 助詞,接続助詞,*,*,*,*,で false
  if (true) and ((lid == 349)) then return false end
  -- * * true
  if (true) and (true) then return true end

  -- Default rule: boundary exists for unmatched cases
  return true
end

-- Export the segmenter module
return segmenter

