<script lang="ts">
    import { onMount } from 'svelte';
    import L from 'leaflet';
    import 'leaflet/dist/leaflet.css';
  
    let map: L.Map;
    let processing = false;
    let resultUrl: string | null = null;
    let progress = 0;
    let eventSource: EventSource | null = null;
  
    onMount(() => {
      initMap();
    });
  
    function initMap() {
      map = L.map('map-container').setView([0, 0], 1);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
      }).addTo(map);
    }
  
    async function uploadFiles(files: FileList) {
      processing = true;
      resultUrl = null;
      progress = 0;
  
      const formData = new FormData();
      Array.from(files).forEach(file => {
        formData.append('files', file);
      });
  
      // Setup progress tracking
      eventSource = new EventSource('/api/progress');
      eventSource.onmessage = (e) => {
        progress = parseInt(e.data);
      };
  
      try {
        const response = await fetch('/api/process', {
          method: 'POST',
          body: formData
        });
        
        const data = await response.json();
        if (data.result) {
          resultUrl = data.result;
          loadResult(data.result);
        }
      } catch (error) {
        console.error('Error:', error);
      } finally {
        processing = false;
        eventSource?.close();
      }
    }
  
    function loadResult(url: string) {
      // Get image dimensions to set bounds
      const img = new Image();
      img.onload = () => {
        const bounds = [[0, 0], [img.height, img.width]];
        L.imageOverlay(url, bounds).addTo(map);
        map.fitBounds(bounds);
      };
      img.src = url;
    }
  </script>
  
  <div class="container">
    <h1>University Building Mapper</h1>
    
    <div class="upload-area">
      <input 
        type="file" 
        id="file-upload" 
        accept="image/*" 
        multiple 
        on:change={(e) => uploadFiles(e.target.files)}
        disabled={processing}
      />
      <label for="file-upload" class:disabled={processing}>
        {#if processing}
          Processing... {progress}%
        {:else}
          Upload Building Photos
        {/if}
      </label>
    </div>
  
    <div id="map-container" style="width: 100%; height: 70vh;"></div>
  
    {#if resultUrl}
      <div class="result-actions">
        <a href={resultUrl} download="floor_plan.png">Download Floor Plan</a>
      </div>
    {/if}
  </div>
  
  <style>
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
    }
    
    .upload-area {
      margin: 20px 0;
    }
    
    #file-upload {
      display: none;
    }
    
    label {
      display: block;
      padding: 15px;
      background: #4CAF50;
      color: white;
      text-align: center;
      border-radius: 5px;
      cursor: pointer;
      transition: background 0.3s;
    }
    
    label:hover:not(.disabled) {
      background: #45a049;
    }
    
    .disabled {
      background: #cccccc;
      cursor: not-allowed;
    }
    
    .result-actions {
      margin-top: 20px;
      text-align: center;
    }
    
    .result-actions a {
      padding: 10px 15px;
      background: #2196F3;
      color: white;
      text-decoration: none;
      border-radius: 5px;
    }
  </style>