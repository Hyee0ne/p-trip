# App Store Connect 자동 입력

스토어 정보를 손으로 옮겨 적지 않는다. **`docs/앱스토어_등록정보.md`가 단일 소스**이고
여기 스크립트가 그 문서의 코드펜스를 읽어 API로 넣는다 —
`core/strings.dart`가 앱 문구의 단일 소스인 것과 같은 이유다.

## 준비

```
~/.appstoreconnect/private_keys/AuthKey_7U29A76MBG.p8   # chmod 600
pip3 install pyjwt cryptography
```

`ascapi.py` 위쪽의 `KEY_ID` · `ISSUER` · `APP`을 확인할 것.

## 쓰는 법

```bash
python3 tools/asc/asc_status.py      # 제출 전 무엇이 비어 있는지 (읽기 전용)
python3 tools/asc/shots.py           # docs/screenshots/*.png 업로드
python3 tools/asc/review_status.py   # 심사 상태 한 줄로
```

심사 상태는 `--quiet`를 붙이면 **지난번과 다를 때만** 출력한다. cron 에 걸 때 쓴다:

```bash
*/30 * * * * cd ~/공모전/trip && python3 tools/asc/review_status.py --quiet
```

## 두 번 겪은 함정

1. **사전서명 업로드 URL에 `Authorization`을 붙이면 400.**
   `uploadOperations`의 URL은 ASC 토큰을 받지 않는다. `requestHeaders`만 그대로 쓴다.
2. **버전 레코드와 빌드의 버전 문자열이 같아야 붙는다.**
   ASC가 만들어준 기본값은 `1.0`인데 우리 빌드는 `1.0.0`이었다. 안 맞으면 빌드가 안 붙는다.

## 반려된 뒤 재제출이 막힐 때

반려 건이 `UNRESOLVED_ISSUES` 상태로 **버전을 붙들고 있다.** 그대로 새 제출을 만들면
`appStoreVersions ... is not in valid state` 로 거부된다 (2026-09-03 실제로 막혔다).
그 건을 먼저 닫는다:

```python
a.patch(f'reviewSubmissions/{OLD_ID}', {'data':{'type':'reviewSubmissions','id':OLD_ID,
  'attributes':{'canceled':True}}})
```

`CANCELING` → `COMPLETE` 로 바뀐 뒤에 새 묶음을 만들어 제출한다.

## API로 안 되는 것

**앱 개인정보(App Privacy) 설문은 공개 API에 없다.** 웹에서만 채운다 —
`appDataUsages` 계열 엔드포인트는 전부 404다.
