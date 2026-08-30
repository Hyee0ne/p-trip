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
cd tools/asc
python3 asc_status.py     # 무엇이 비어 있는지 (읽기 전용)
python3 shots.py          # docs/screenshots/*.png 업로드
```

## 두 번 겪은 함정

1. **사전서명 업로드 URL에 `Authorization`을 붙이면 400.**
   `uploadOperations`의 URL은 ASC 토큰을 받지 않는다. `requestHeaders`만 그대로 쓴다.
2. **버전 레코드와 빌드의 버전 문자열이 같아야 붙는다.**
   ASC가 만들어준 기본값은 `1.0`인데 우리 빌드는 `1.0.0`이었다. 안 맞으면 빌드가 안 붙는다.

## API로 안 되는 것

**앱 개인정보(App Privacy) 설문은 공개 API에 없다.** 웹에서만 채운다 —
`appDataUsages` 계열 엔드포인트는 전부 404다.
