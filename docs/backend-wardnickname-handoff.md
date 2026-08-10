# `wardNickname`이 항상 null로 내려갑니다 — 수정 요청

> 작성: 프론트(이건) · 2026-08-10 · 대상: SafeFam_BE 담당
> 근거: `SafeFam_BE` develop 원격 소스 대조 (PR #93 `9af28c6` 기준)
> **한 줄 요약**: `FamilyMemberResponse`가 `getNickname()`을 읽는데 그 컬럼은 아무도 안 채웁니다. `getName()`으로 바꿔주세요.

---

## 1. 증상

`GET /api/v1/family/members` 응답의 **`wardNickname`이 모든 사용자에게 `null`** 로 내려갑니다.

```json
{
  "linkId": 12,
  "wardId": 34,
  "wardNickname": null,        ← 항상 null
  "wardPhone": "01012345678",
  "relationship": "어머니",
  "status": "ACTIVE",
  "linkedAt": "2026-08-10T18:00:00+09:00"
}
```

---

## 2. 원인

`FamilyMemberResponse.java:23`이 `User.nickname`을 읽습니다.

```java
// src/main/java/com/gold/safefam/domain/family/dto/FamilyMemberResponse.java:23
link.getWard() != null ? link.getWard().getNickname() : null,
```

그런데 `nickname`은 **V1 스키마의 레거시 컬럼**이고, V2에서 `name`으로 이관됐습니다.

```sql
-- src/main/resources/db/migration/V2__add_email_signup_fields.sql:11-13
UPDATE users
SET name = COALESCE(name, nickname, '사용자')
WHERE name IS NULL;
```

**이관 이후 `nickname`에 값을 넣는 코드가 없습니다.**

| 확인 항목 | 결과 |
|---|---|
| 일반 가입 (`AuthService.java:51`) | `new User(phoneNumber, encodedPassword, request.name())` — `name`만 |
| 카카오 가입 (`AuthService.java:190`) | `User.ofKakao(kakaoId, phoneNumber, request.name())` — `name`만 |
| 이름 수정 (`AuthService.java:198`) | `user.updateName(request.name())` — `name`만 |
| `User` 엔티티 setter | `updateName`은 있고 **`updateNickname`은 없음** |
| `nickname`을 참조하는 코드 전체 | `User.java:32-33`(필드 선언) + `FamilyMemberResponse.java:23`(조회) — **이 둘뿐** |

→ V2 이후 가입한 사용자(= 현재 전원)는 `nickname`이 항상 `NULL`입니다.

---

## 3. 실수로 판단한 근거

같은 도메인의 다른 DTO는 전부 `getName()`을 씁니다.

```java
// src/main/java/com/gold/safefam/domain/family/safety/dto/FamilySafetyCaseResponse.java
:41   safetyCase.getWard().getName(),
:54   safetyCase.getCalledBy() != null ? safetyCase.getCalledBy().getName() : null,
:57   safetyCase.getHandledBy() != null ? safetyCase.getHandledBy().getName() : null,
```

그래서 **가족 안전 알림에는 피보호자 이름이 정상 표시**되는데, **가족 목록에서만 안 나오는** 상태입니다.

---

## 4. 요청

`FamilyMemberResponse.java:23` 한 줄 변경.

```diff
- link.getWard() != null ? link.getWard().getNickname() : null,
+ link.getWard() != null ? link.getWard().getName() : null,
```

---

## 5. 프론트 영향 — **없습니다**

BE만 고치면 즉시 반영됩니다. 프론트는 이미 폴백이 들어가 있습니다 (FE PR #103).

```
표시 이름 = relationship → wardNickname → wardPhone
```

- **지금**: 보호자가 설정한 `relationship`으로 정상 동작 중
- **고친 뒤**: 관계를 아직 설정하지 않은 가족도 **번호 대신 실명**이 보임

프론트 재배포 없이 서버 수정만으로 개선됩니다.

---

## 6. 참고 — 별건, 지금 당장 문제는 아님

`User.nickname` 필드는 사실상 죽은 컬럼입니다(V1에서 생성 후 아무도 안 씀, V2 이후 미사용).

정리하실 경우 **`ddl-auto: validate` 설정이라 DB 컬럼과 엔티티 필드를 함께 지워야** 기동이 깨지지 않습니다.

```
application.yml:14   ddl-auto: validate
```

- 컬럼만 드롭 → 엔티티에 `nickname`이 남아 **검증 실패로 기동 불가**
- 엔티티 필드만 삭제 → 컬럼은 남지만 기동에는 지장 없음 (V1에 생성, 드롭한 적 없음)

급하지 않으니 여유 있을 때 정리해도 됩니다.

---

## 7. 확인에 사용한 커맨드 (재현용)

```bash
# nickname을 참조하는 코드 전체
grep -rn "nickname\|Nickname" src/main/java --include=*.java

# 마이그레이션에서의 nickname 취급
grep -rn "nickname" src/main/resources/db/migration/

# 가입 시 어떤 필드를 채우는지
grep -rn "new User(\|User.ofKakao\|updateName" src/main/java/com/gold/safefam/domain/auth/service/
```
