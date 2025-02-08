package main

import (
    "encoding/json"
    "fmt"
    "io/ioutil"
    "os"
    "os/exec"
    "strings"
)

type GUIOption struct {
    Name      string `json:"name"`
    Repo      string `json:"repo"`
    Installer string `json:"installer"`
}

func main() {
    // Display header
    displayHeader()

    // Read and parse GUI options
    guiOptions, err := readGUIOptions("firstBoot/gui_options.json")
    if err != nil {
        fmt.Println("Error reading GUI options:", err)
        return
    }

    // Display GUI options and get user choice
    choice := getUserChoice(guiOptions)

    // Install selected GUI
    if choice != "None" {
        err := installGUI(guiOptions[choice])
        if err != nil {
            fmt.Println("Error installing GUI:", err)
        }
    }

    // Final steps
    fmt.Println("First boot setup complete. Rebooting...")
    exec.Command("reboot").Run()
}

func displayHeader() {
    fmt.Println(`
   __                    _      ___    ___    ___    ___  
   \ \ __      __  __ _ | | __ / _ \  / _ \  / _ \  / _ \ 
    \ \\ \ /\ / / / _` || |/ /| (_) || | | || | | || | | |
 /\_/ / \ V  V / | (_| ||   <  \__, || |_| || |_| || |_| |
 \___/   \_/\_/   \__,_||_|\_\   /_/  \___/  \___/  \___/ 
                                                          
   _____              _           _  _                      
   \_   \ _ __   ___ | |_   __ _ | || |  ___  _ __         
    / /\/| '_ \ / __|| __| / _` || || | / _ \| '__|        
 /\/ /_  | | | |\__ \| |_ | (_| || || ||  __/| |           
 \____/  |_| |_||___/ \__| \__,_||_||_| \___||_|     
    `)
}

func readGUIOptions(filePath string) (map[string]GUIOption, error) {
	file, err := ioutil.ReadFile(filePath)
    if err != nil {
        return nil, err
    }

    var options []GUIOption
    err = json.Unmarshal(file, &options)
    if err != nil {
        return nil, err
    }

    optionMap := make(map[string]GUIOption)
    for _, option := range options {
        optionMap[option.Name] = option
    }

    return optionMap, nil
}

func getUserChoice(options map[string]GUIOption) string {
    fmt.Println("Choose an optional GUI to install:")
    names := make([]string, 0, len(options))
    for name := range options {
        names = append(names, name)
    }
    names = append(names, "None")

    for i, name := range names {
        fmt.Printf("%d) %s\n", i+1, name)
    }

    var choice int
    fmt.Print("Enter the number corresponding to your choice: ")
    fmt.Scan(&choice)

    if choice < 1 || choice > len(names) {
        fmt.Println("Invalid choice. Please try again.")
        return getUserChoice(options)
    }

    return names[choice-1]
}

func installGUI(option GUIOption) error {
    fmt.Printf("Installing %s...\n", option.Name)
    cmd := exec.Command("git", "clone", option.Repo, "/tmp/gui_repo")
    err := cmd.Run()
    if err != nil {
        return err
    }

    cmd = exec.Command("bash", "/tmp/gui_repo/"+option.Installer)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    return cmd.Run()
}