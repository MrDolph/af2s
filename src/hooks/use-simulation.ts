import { useCallback } from 'react';
import { useSimulationStore } from '@/store/simulation-store';
import type { AIPromptResponse } from '@/types/ai';
import type { SimulationScene } from '@/types/simulation';

export function useSimulation() {
  const store = useSimulationStore();

  const loadFromAIResponse = useCallback((response: AIPromptResponse) => {
    const scene: SimulationScene = {
      id: crypto.randomUUID(),
      type: response.simulationType,
      title: response.title,
      description: response.description,
      params: response.params,
      createdAt: new Date().toISOString(),
    };
    store.setScene(scene);
  }, [store]);

  return {
    scene: store.currentScene,
    isRunning: store.isRunning,
    isPaused: store.isPaused,
    elapsedTime: store.elapsedTime,
    graphData: store.graphData,
    loadFromAIResponse,
    start: useCallback(() => { store.setRunning(true); store.setPaused(false); }, [store]),
    pause: useCallback(() => { store.setPaused(!store.isPaused); }, [store]),
    reset: useCallback(() => { store.reset(); }, [store]),
  };
}
