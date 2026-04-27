 ---                                                                      
  버그 분석: 게임오버 직전 카드 선택 UI 충돌                               
                                                                           
  전체 게임오버 흐름                                                       
                                                                           
  뱀이 끝 도달                                                             
      └─ BaseSnakeController.GameOver()                                    
           ├─ isGameOverProcess = true (static)
           └─ DelayedGameOverAsync().Forget()  ← 비동기, fire-and-forget   
                    └─ ShowAsync<GameRetryUI>()  ← Time.timeScale = 0      
                    └─ await ReceiveAsync<OnClickAdContinue>()  ← 플레이어 
  응답 대기                                                                
                         ├─ (Continue) → isGameOverProcess = false, return
                         └─ (Give up) → ForceCloseCardSelectionUI() →      
  SendGameOverEvent()                                                      
                                             └─ HandleGameOver() →         
  StopStage()                                                              
                                                  └─ IsStageActive = false
   ← 여기서야 false                                                        
                  
  핵심 문제: IsStageActive는 GameRetryUI가 떠 있는 내내 true로 유지됩니다. 
                  
  ---                                                                      
  버그 원인 (근본): CardManager와 GameOver의 독립적 실행
                                                                           
  CardManager.ProcessCardSelectionQueueAsync가 게임오버 상태를 전혀
  인지하지 못합니다.                                                       
                  
  CardManager.IsGameActive() (CardManager.cs:4914):                        
  private bool IsGameActive()
  {                                                                        
      var stageManager = Managers.Instance.GetManager<StageManager>();
      bool isStageActive = stageManager.IsStageActive;                
      if (!isStageActive) return false;                                    
      // ← GameRetryUI가 열려있는지 전혀 체크하지 않음
      return true;                                                         
  }                                                                        
                                                                           
  CardManager의 딜레이는 전부 UnscaledDeltaTime:                           
  await UniTask.Delay(100, DelayType.UnscaledDeltaTime, cancellationToken: 
  token);                                                                 
                                                                           
  Time.timeScale = 0이어도 CardManager의 비동기 루프는 계속 돕니다.
                                                                           
  CardManager._cardSelectionProcessCts는 게임오버 시 취소되지 않습니다.    
  ResetInGameData()가 취소하는데, 이 함수는 StageStarted 이벤트에서만      
  호출됩니다.                                                              
                  
  ---
  버그 시나리오 A: 가장 흔한 케이스
                                                                           
  [Frame N]   정예/보스 처치 → EnqueueEliteCardSelectionRequest()
              ProcessCardSelectionQueueAsync 시작                          
              (내부에서 await Delay(100ms, UnscaledDeltaTime) 중)          
                                                                           
  [Frame N+1] 뱀 끝 도달 → GameOver() → isGameOverProcess=true             
              DelayedGameOverAsync() 시작                                  
              → GameRetryUI 표시, Time.timeScale = 0                       
                                                                           
  [100ms 후]  ProcessCardSelectionQueueAsync 깨어남
              IsGameActive() → IsStageActive = true → true 반환!  ← 버그   
              WaitForExistingUIToComplete() → CardSelectionUI 없음 → 통과! 
              → GenerateCardChoices() 호출                                 
              → CardSelectionUI가 GameRetryUI 위에 열림                    
                                                                           
  버그 시나리오 B: 카드 선택 도중 뱀이 들어오는 케이스                     
                                                                           
  [상태] CardSelectionUI가 열려있음, IsCardSelectionActive = true          
         WaitForCardSelectionComplete() 대기 중                            
                                                                           
  [동시] 뱀 끝 도달 → DelayedGameOverAsync()                               
         → 기존 GameRetryUI 없음 → ShowAsync<GameRetryUI>()                
         → 두 UI가 동시에 열림 (CardSelection + GameRetry)                 
                                                                           
  플레이어가 카드 선택 → CardSelectionUI 닫힘                              
  → GameRetryUI가 뒤에서 나타남 (플레이어 혼란)                            
                                                                           
  버그 시나리오 C: 부활 애니메이션 1.1초 중 카드 등장                      
   
  // GameRetryUI.cs:404                                                    
  marineAnimator.Play("Respawn_Start");
  await UniTask.Delay(TimeSpan.FromSeconds(1.1f), true); // ← unscaled,    
  timeScale=0                                                              
  RocketDan.Msg.Publish(new OnClickAdContinue(true, ...));                 
  uiManager?.Hide<GameRetryUI>(); // ← 여기서야 Closed() →                 
  RestoreTimeScale()                                                       
                                                                           
  플레이어가 "계속하기"를 눌러도 1.1초 동안 Time.timeScale = 0 +           
  IsStageActive = true 상태가 유지됩니다. 이 사이에 CardManager가 큐를
  처리하면 부활 애니메이션 중에 카드 선택 UI가 나타납니다.                 
                  
  ---
  버그가 간헐적인 이유

  ┌─────────────────────┬──────────────────────────────────────────────┐
  │        조건         │                     상세                     │
  ├─────────────────────┼──────────────────────────────────────────────┤   
  │ 정확한 타이밍 필요  │ 정예/보스 사망 + 뱀 도착이 수 프레임 차이 내 │
  │                     │  발생                                        │   
  ├─────────────────────┼──────────────────────────────────────────────┤   
  │ CardManager 큐      │ 100ms await 도중 race window 발생            │
  │ 딜레이              │                                              │   
  ├─────────────────────┼──────────────────────────────────────────────┤
  │ 재현 어려움         │ 테스트에선 게임 진행 속도가 달라 타이밍이    │   
  │                     │ 맞지 않음                                    │   
  └─────────────────────┴──────────────────────────────────────────────┘
                                                                           
  ---             
  ForceCloseCardSelectionUI의 한계
                                  
  // BaseSnakeController.cs:920
  private void ForceCloseCardSelectionUI()                                 
  {
      var cardSelectionUI = uiManager.IsOpened<CardSelectionUI>();         
      if (cardSelectionUI != null)                                         
          uiManager.Hide<CardSelectionUI>(); // UI만 닫음
      // ← CardManager의 _cardSelectionProcessCts를 취소하지 않음          
      // ← 큐가 비어있지 않으면 다음 항목이 또 처리됨                      
  }                                                                        
                                                                           
  UI를 닫아도 CardManager의 큐와 CTS는 살아있어서, 게임오버 직후에도 새    
  카드 선택이 다시 열릴 수 있습니다.                                       
                                                                           
  ---             
  수정 방향
           
  CardManager.IsGameActive()에 GameRetryUI 체크 추가 (가장 간단):
  private bool IsGameActive()                                              
  {                          
      var stageManager = Managers.Instance.GetManager<StageManager>();     
      if (!stageManager.IsStageActive) return false;                  
                                                                           
      // 추가: 게임오버 UI가 열려있으면 카드 선택 중단
      var uiManager = Managers.Instance.GetManager<UIManager>();           
      if (uiManager?.IsOpened<GameRetryUI>() != null) return false;
      if (uiManager?.IsOpened<ArkGameRetryUI>() != null) return false;     
                                                                           
      return true;                                                         
  }                                                                        
                  
  또는 DelayedGameOverAsync에서 카드 큐 즉시 취소:                         
  // BaseSnakeController.DelayedGameOverAsync 진입 시
  var cardManager = Managers.Instance?.GetManager<CardManager>();          
  cardManager?.ForceStopCardSelectionQueue(); // CTS 취소 + 큐 클리어 + UI 
  닫기                                                                     
                                                                           
  두 방법 중 IsGameActive() 수정이 더 방어적이고 두 시나리오를 모두
  커버합니다. CompleteAction의 1.1초 딜레이 동안도 GameRetryUI가           
  열려있으므로 차단됩니다.