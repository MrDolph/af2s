import { create } from 'zustand';
import type { SimulationScene, SimulationState, GraphDataPoint } from '@/types/simulation';

interface SimulationStore extends SimulationState {
  setScene: (scene: SimulationScene) => void;
  setRunning: (running: boolean) => void;
  setPaused: (paused: boolean) => void;
  updateElapsedTime: (time: number) => void;
  setGraphData: (data: GraphDataPoint[]) => void;
  reset: () => void;
}

const initialState: SimulationState = {
  isRunning: false, isPaused: false, elapsedTime: 0, graphData: [], currentScene: null,
};

export const useSimulationStore = create<SimulationStore>((set) => ({
  ...initialState,
  setScene: (scene) => set({ currentScene: scene, isRunning: false, elapsedTime: 0, graphData: [] }),
  setRunning: (isRunning) => set({ isRunning }),
  setPaused: (isPaused) => set({ isPaused }),
  updateElapsedTime: (elapsedTime) => set({ elapsedTime }),
  setGraphData: (graphData) => set({ graphData }),
  reset: () => set(initialState),
}));
